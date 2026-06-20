import 'dart:async';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'gtfs_bus_stop_service.dart';

// ── Public model ──────────────────────────────────────────────────────────────

class GtfsArrival {
  final String routeId;     // e.g. "T810"
  final String direction;   // trip_headsign
  final int? eta1Min;       // minutes to first arrival
  final int? eta2Min;       // minutes to second arrival
  final bool isLive;        // always false (schedule-based)

  const GtfsArrival({
    required this.routeId,
    required this.direction,
    this.eta1Min,
    this.eta2Min,
    this.isLive = false,
  });
}

// ── Internal index types ──────────────────────────────────────────────────────

class _StopTime {
  final String tripId;
  final int arrivalSecs; // seconds past midnight (template time)
  const _StopTime(this.tripId, this.arrivalSecs);
}

class _Trip {
  final String routeId;
  final String serviceId;
  final String headsign;
  const _Trip(this.routeId, this.serviceId, this.headsign);
}

class _Calendar {
  final String startDate; // YYYYMMDD
  final String endDate;
  final List<bool> days;  // index 0=Mon … 6=Sun
  const _Calendar(this.startDate, this.endDate, this.days);
}

/// One frequency band for a trip (from frequencies.txt).
class _Frequency {
  final int startSecs;   // service start time (secs past midnight)
  final int endSecs;     // service end time
  final int headwaySecs; // interval between departures
  const _Frequency(this.startSecs, this.endSecs, this.headwaySecs);
}

class _GtfsScheduleIndex {
  final Map<String, List<_StopTime>> byStop;         // stop_id → template times
  final Map<String, _Trip> trips;                    // trip_id → Trip
  final Map<String, String> routeNames;              // route_id → short_name
  final Map<String, _Calendar> calendar;             // service_id → Calendar
  final Map<String, Map<String, int>> caldates;      // service_id → date → type
  final Map<String, List<_Frequency>> freqs;         // trip_id → frequencies
  final Map<String, int> tripBaseTimes;              // trip_id → first stop secs

  const _GtfsScheduleIndex({
    required this.byStop,
    required this.trips,
    required this.routeNames,
    required this.calendar,
    required this.caldates,
    required this.freqs,
    required this.tripBaseTimes,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class GtfsScheduleService {
  static _GtfsScheduleIndex? _cache;
  static String? _cacheDate;
  static Completer<_GtfsScheduleIndex>? _inFlight;

  /// Pre-warms the schedule index. Call in background after stops are loaded.
  static void preload() {
    _load().ignore();
  }

  static Future<_GtfsScheduleIndex> _load() async {
    final today = GtfsBusStopService.today();
    if (_cache != null && _cacheDate == today) return _cache!;
    if (_inFlight != null) return _inFlight!.future;

    final completer = Completer<_GtfsScheduleIndex>();
    _inFlight = completer;

    try {
      debugPrint('[GtfsSchedule] Loading raw bytes…');
      final bytes = await GtfsBusStopService.getRawBytes();

      debugPrint('[GtfsSchedule] Parsing schedule in isolate…');
      final index = await compute(_parseScheduleInIsolate, bytes);

      if (index.calendar.isNotEmpty) {
        final s = index.calendar.entries.first;
        debugPrint('[GtfsSchedule] Sample calendar: '
            '${s.key} → ${s.value.startDate}–${s.value.endDate}');
      }
      debugPrint('[GtfsSchedule] Index ready: '
          '${index.byStop.length} stops, ${index.trips.length} trips, '
          '${index.freqs.length} frequency trips');

      _cache = index;
      _cacheDate = today;
      _inFlight = null;
      completer.complete(index);
      return index;
    } catch (e, st) {
      _inFlight = null;
      debugPrint('[GtfsSchedule] Error: $e\n$st');
      completer.completeError(e);
      rethrow;
    }
  }

  /// Returns upcoming arrivals for [stopId] within [windowMinutes].
  static Future<List<GtfsArrival>> getArrivals(
    String stopId, {
    int windowMinutes = 90,
  }) async {
    final index = await _load();

    final now = DateTime.now();
    final nowSecs = now.hour * 3600 + now.minute * 60 + now.second;
    final limitSecs = nowSecs + windowMinutes * 60;
    final dateStr = _dateStr(now);
    final dayIdx = now.weekday - 1; // Mon=0 … Sun=6

    final times = index.byStop[stopId];
    debugPrint('[GtfsSchedule] getArrivals($stopId): '
        '${times?.length ?? 0} template entries, '
        'date=$dateStr dayIdx=$dayIdx '
        'now=${nowSecs}s limit=${limitSecs}s');

    if (times == null || times.isEmpty) {
      debugPrint('[GtfsSchedule] No stop_times entries for $stopId');
      return [];
    }

    // Pass 1: strict (date range + day-of-week + calendar_dates)
    var result = _collectArrivals(times, nowSecs, limitSecs, index,
        dateStr, dayIdx, strict: true);
    debugPrint('[GtfsSchedule] Pass1 strict: ${result.length} routes');

    // Pass 2: day-of-week only (handles stale GTFS date ranges)
    if (result.isEmpty) {
      result = _collectArrivals(times, nowSecs, limitSecs, index,
          dateStr, dayIdx, strict: false);
      debugPrint('[GtfsSchedule] Pass2 dayOfWeek: ${result.length} routes');
    }

    return result;
  }

  static List<GtfsArrival> _collectArrivals(
    List<_StopTime> times,
    int nowSecs,
    int limitSecs,
    _GtfsScheduleIndex index,
    String dateStr,
    int dayIdx, {
    required bool strict,
  }) {
    final Map<String, List<int>> routeTimes = {};
    final Map<String, String> routeHead = {};
    int cntFreq = 0, cntSched = 0, cntSkip = 0;

    for (final st in times) {
      final trip = index.trips[st.tripId];
      if (trip == null) { cntSkip++; continue; }

      // Service day check
      final runs = strict
          ? _serviceRunsStrict(trip.serviceId, dateStr, dayIdx,
              index.calendar, index.caldates)
          : _serviceRunsDayOnly(trip.serviceId, dayIdx, index.calendar);
      if (!runs) { cntSkip++; continue; }

      final freqList = index.freqs[st.tripId];

      if (freqList != null && freqList.isNotEmpty) {
        // ── Frequency-based: expand template time across service bands ──────
        // offset = how far into the trip this stop is
        final base = index.tripBaseTimes[st.tripId] ?? st.arrivalSecs;
        final offsetSecs = st.arrivalSecs - base;

        for (final freq in freqList) {
          // Walk through each trip departure in this frequency band
          int tripDep = freq.startSecs;
          while (tripDep + offsetSecs <= freq.endSecs) {
            final actualSecs = tripDep + offsetSecs;
            if (actualSecs >= nowSecs && actualSecs <= limitSecs) {
              routeTimes.putIfAbsent(trip.routeId, () => []).add(actualSecs);
              routeHead[trip.routeId] ??= trip.headsign;
              cntFreq++;
            }
            tripDep += freq.headwaySecs;
            if (freq.headwaySecs <= 0) break; // safety
          }
        }
      } else {
        // ── Schedule-based: use template time directly ─────────────────────
        if (st.arrivalSecs >= nowSecs && st.arrivalSecs <= limitSecs) {
          routeTimes.putIfAbsent(trip.routeId, () => []).add(st.arrivalSecs);
          routeHead[trip.routeId] ??= trip.headsign;
          cntSched++;
        }
      }
    }

    debugPrint('[GtfsSchedule] freq_hits=$cntFreq sched_hits=$cntSched skipped=$cntSkip routes=${routeTimes.length}');

    if (routeTimes.isEmpty) return [];

    final result = <GtfsArrival>[];
    for (final entry in routeTimes.entries) {
      final sorted = entry.value..sort();
      final routeId = entry.key;
      final shortName = index.routeNames[routeId] ?? routeId;

      final eta1 = ((sorted[0] - nowSecs) / 60).round().clamp(0, 999);
      final eta2 = sorted.length > 1
          ? ((sorted[1] - nowSecs) / 60).round().clamp(0, 999)
          : null;

      result.add(GtfsArrival(
        routeId: shortName,
        direction: routeHead[routeId] ?? '',
        eta1Min: eta1,
        eta2Min: eta2,
        isLive: false,
      ));
    }

    result.sort((a, b) => (a.eta1Min ?? 999).compareTo(b.eta1Min ?? 999));
    return result;
  }

  static bool _serviceRunsStrict(
    String serviceId,
    String dateStr,
    int dayIdx,
    Map<String, _Calendar> calendar,
    Map<String, Map<String, int>> caldates,
  ) {
    final ex = caldates[serviceId]?[dateStr];
    if (ex == 1) return true;
    if (ex == 2) return false;
    final cal = calendar[serviceId];
    if (cal == null) return false;
    if (dateStr.compareTo(cal.startDate) < 0 ||
        dateStr.compareTo(cal.endDate) > 0) return false;
    return cal.days[dayIdx];
  }

  static bool _serviceRunsDayOnly(
    String serviceId,
    int dayIdx,
    Map<String, _Calendar> calendar,
  ) {
    final cal = calendar[serviceId];
    if (cal == null) return false;
    return cal.days[dayIdx];
  }

  static String _dateStr(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

  static void clearCache() {
    _cache = null;
    _cacheDate = null;
  }
}

// ── Isolate parser ─────────────────────────────────────────────────────────────

_GtfsScheduleIndex _parseScheduleInIsolate(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);

  String? routesCsv, tripsCsv, calCsv, calDatesCsv, stopTimesCsv, freqCsv;
  for (final f in archive) {
    if (!f.isFile) continue;
    final name = f.name.split('/').last.toLowerCase();
    switch (name) {
      case 'routes.txt':
        routesCsv = String.fromCharCodes(f.content as List<int>);
      case 'trips.txt':
        tripsCsv = String.fromCharCodes(f.content as List<int>);
      case 'calendar.txt':
        calCsv = String.fromCharCodes(f.content as List<int>);
      case 'calendar_dates.txt':
        calDatesCsv = String.fromCharCodes(f.content as List<int>);
      case 'stop_times.txt':
        stopTimesCsv = String.fromCharCodes(f.content as List<int>);
      case 'frequencies.txt':
        freqCsv = String.fromCharCodes(f.content as List<int>);
    }
  }

  // ── routes.txt ────────────────────────────────────────────────────────────
  final routeNames = <String, String>{};
  if (routesCsv != null) {
    final lines = routesCsv.split('\n');
    if (lines.isNotEmpty) {
      final h = _header(lines[0]);
      final iId = h['route_id'] ?? -1;
      final iShort = h['route_short_name'] ?? -1;
      final iLong = h['route_long_name'] ?? -1;
      for (int i = 1; i < lines.length; i++) {
        final c = _csvSplit(lines[i]);
        if (c.isEmpty) continue;
        final id = _cell(c, iId);
        if (id.isEmpty) continue;
        final short = _cell(c, iShort);
        final long = _cell(c, iLong);
        routeNames[id] = short.isNotEmpty ? short : long;
      }
    }
  }

  // ── trips.txt ─────────────────────────────────────────────────────────────
  final trips = <String, _Trip>{};
  if (tripsCsv != null) {
    final lines = tripsCsv.split('\n');
    if (lines.isNotEmpty) {
      final h = _header(lines[0]);
      final iTrip = h['trip_id'] ?? -1;
      final iRoute = h['route_id'] ?? -1;
      final iService = h['service_id'] ?? -1;
      final iHead = h['trip_headsign'] ?? -1;
      for (int i = 1; i < lines.length; i++) {
        final c = _csvSplit(lines[i]);
        if (c.isEmpty) continue;
        final tripId = _cell(c, iTrip);
        if (tripId.isEmpty) continue;
        trips[tripId] = _Trip(
          _cell(c, iRoute),
          _cell(c, iService),
          _cell(c, iHead),
        );
      }
    }
  }

  // ── calendar.txt ──────────────────────────────────────────────────────────
  final calendar = <String, _Calendar>{};
  if (calCsv != null) {
    final lines = calCsv.split('\n');
    if (lines.isNotEmpty) {
      final h = _header(lines[0]);
      final iSvc = h['service_id'] ?? -1;
      final iStart = h['start_date'] ?? -1;
      final iEnd = h['end_date'] ?? -1;
      const dayCols = [
        'monday', 'tuesday', 'wednesday', 'thursday',
        'friday', 'saturday', 'sunday',
      ];
      final iDays = dayCols.map((k) => h[k] ?? -1).toList();
      for (int i = 1; i < lines.length; i++) {
        final c = _csvSplit(lines[i]);
        if (c.isEmpty) continue;
        final svcId = _cell(c, iSvc);
        if (svcId.isEmpty) continue;
        final days = iDays
            .map((idx) => idx >= 0 && idx < c.length && c[idx].trim() == '1')
            .toList();
        calendar[svcId] = _Calendar(_cell(c, iStart), _cell(c, iEnd), days);
      }
    }
  }

  // ── calendar_dates.txt ────────────────────────────────────────────────────
  final caldates = <String, Map<String, int>>{};
  if (calDatesCsv != null) {
    final lines = calDatesCsv.split('\n');
    if (lines.isNotEmpty) {
      final h = _header(lines[0]);
      final iSvc = h['service_id'] ?? -1;
      final iDate = h['date'] ?? -1;
      final iType = h['exception_type'] ?? -1;
      for (int i = 1; i < lines.length; i++) {
        final c = _csvSplit(lines[i]);
        if (c.isEmpty) continue;
        final svcId = _cell(c, iSvc);
        final date = _cell(c, iDate);
        final type = int.tryParse(_cell(c, iType)) ?? 0;
        if (svcId.isEmpty || date.isEmpty || type == 0) continue;
        caldates.putIfAbsent(svcId, () => {})[date] = type;
      }
    }
  }

  // ── frequencies.txt ───────────────────────────────────────────────────────
  // trip_id, start_time, end_time, headway_secs[, exact_times]
  final freqs = <String, List<_Frequency>>{};
  if (freqCsv != null) {
    final lines = freqCsv.split('\n');
    if (lines.isNotEmpty) {
      final h = _header(lines[0]);
      final iTrip = h['trip_id'] ?? -1;
      final iStart = h['start_time'] ?? -1;
      final iEnd = h['end_time'] ?? -1;
      final iHeadway = h['headway_secs'] ?? -1;
      for (int i = 1; i < lines.length; i++) {
        final c = _csvSplit(lines[i]);
        if (c.isEmpty) continue;
        final tripId = _cell(c, iTrip);
        if (tripId.isEmpty) continue;
        final startSecs = _parseTime(_cell(c, iStart));
        final endSecs = _parseTime(_cell(c, iEnd));
        final headway = int.tryParse(_cell(c, iHeadway)) ?? 0;
        if (startSecs < 0 || endSecs < 0 || headway <= 0) continue;
        freqs.putIfAbsent(tripId, () => [])
            .add(_Frequency(startSecs, endSecs, headway));
      }
    }
  }

  // ── stop_times.txt ────────────────────────────────────────────────────────
  // Store template times AND track each trip's base (first-stop) time.
  final byStop = <String, List<_StopTime>>{};
  final tripBaseTimes = <String, int>{}; // trip_id → minimum arrival secs

  if (stopTimesCsv != null) {
    final lines = stopTimesCsv.split('\n');
    if (lines.isNotEmpty) {
      final h = _header(lines[0]);
      final iTrip = h['trip_id'] ?? -1;
      final iArrival = h['arrival_time'] ?? -1;
      final iStopId = h['stop_id'] ?? -1;

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i];
        if (line.isEmpty) continue;
        final c = _csvSplit(line);
        if (c.isEmpty) continue;

        final tripId = _cell(c, iTrip);
        final stopId = _cell(c, iStopId);
        if (tripId.isEmpty || stopId.isEmpty) continue;
        if (!trips.containsKey(tripId)) continue;

        final arrSecs = _parseTime(_cell(c, iArrival));
        if (arrSecs < 0) continue;

        byStop.putIfAbsent(stopId, () => []).add(_StopTime(tripId, arrSecs));

        // Track trip's first (minimum) stop time as base for offset calc
        final existing = tripBaseTimes[tripId];
        if (existing == null || arrSecs < existing) {
          tripBaseTimes[tripId] = arrSecs;
        }
      }
    }
  }

  return _GtfsScheduleIndex(
    byStop: byStop,
    trips: trips,
    routeNames: routeNames,
    calendar: calendar,
    caldates: caldates,
    freqs: freqs,
    tripBaseTimes: tripBaseTimes,
  );
}

// ── CSV helpers ────────────────────────────────────────────────────────────────

Map<String, int> _header(String line) {
  final cols = _csvSplit(line);
  final map = <String, int>{};
  for (int i = 0; i < cols.length; i++) {
    final k = cols[i].trim().replaceAll('\uFEFF', '').toLowerCase();
    map[k] = i;
  }
  return map;
}

String _cell(List<String> cols, int idx) {
  if (idx < 0 || idx >= cols.length) return '';
  return cols[idx].trim();
}

List<String> _csvSplit(String line) {
  final result = <String>[];
  final buf = StringBuffer();
  bool inQ = false;
  for (int i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      inQ = !inQ;
    } else if (c == ',' && !inQ) {
      result.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  result.add(buf.toString());
  return result;
}

int _parseTime(String t) {
  final parts = t.split(':');
  if (parts.length != 3) return -1;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final s = int.tryParse(parts[2]);
  if (h == null || m == null || s == null) return -1;
  return h * 3600 + m * 60 + s;
}
