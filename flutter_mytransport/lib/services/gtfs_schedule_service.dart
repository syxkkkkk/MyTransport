import 'dart:async';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'gtfs_bus_stop_service.dart';

// ── Public models ─────────────────────────────────────────────────────────────

class GtfsArrival {
  final String routeId;     // short name, e.g. "T810"
  final String direction;   // trip_headsign
  final int? eta1Min;
  final int? eta2Min;
  final bool isLive;

  const GtfsArrival({
    required this.routeId,
    required this.direction,
    this.eta1Min,
    this.eta2Min,
    this.isLive = false,
  });
}

class RouteStopItem {
  final String stopId;
  final String stopName;
  const RouteStopItem({required this.stopId, required this.stopName});
}

class RouteDetail {
  final String routeShortName;
  final String headsign;
  final int directionId;
  final bool hasOtherDirection;
  final List<RouteStopItem> stops;
  final int currentStopIndex;       // index of the selected stop in [stops]
  final List<String> allScheduledTimes; // "08:10 am" strings
  final String? nextDepartureStr;

  const RouteDetail({
    required this.routeShortName,
    required this.headsign,
    required this.directionId,
    required this.hasOtherDirection,
    required this.stops,
    required this.currentStopIndex,
    required this.allScheduledTimes,
    this.nextDepartureStr,
  });
}

// ── Internal index types ──────────────────────────────────────────────────────

class _TripStop {
  final String stopId;
  final int seq;
  const _TripStop(this.stopId, this.seq);
}

class _StopTime {
  final String tripId;
  final int arrivalSecs;
  const _StopTime(this.tripId, this.arrivalSecs);
}

class _Trip {
  final String routeId;
  final String serviceId;
  final String headsign;
  final int directionId; // 0 or 1
  const _Trip(this.routeId, this.serviceId, this.headsign, this.directionId);
}

class _Calendar {
  final String startDate;
  final String endDate;
  final List<bool> days; // 0=Mon … 6=Sun
  const _Calendar(this.startDate, this.endDate, this.days);
}

class _Frequency {
  final int startSecs;
  final int endSecs;
  final int headwaySecs;
  const _Frequency(this.startSecs, this.endSecs, this.headwaySecs);
}

class _GtfsScheduleIndex {
  final Map<String, List<_StopTime>> byStop;       // stop_id → template times
  final Map<String, List<_TripStop>> tripStops;    // trip_id → ordered stops
  final Map<String, String> stopNames;             // stop_id → stop_name
  final Map<String, _Trip> trips;                  // trip_id → Trip
  final Map<String, String> routeNames;            // route_id → short_name
  final Map<String, _Calendar> calendar;
  final Map<String, Map<String, int>> caldates;
  final Map<String, List<_Frequency>> freqs;
  final Map<String, int> tripBaseTimes;

  const _GtfsScheduleIndex({
    required this.byStop,
    required this.tripStops,
    required this.stopNames,
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

  static void preload() => _load().ignore();

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

      debugPrint('[GtfsSchedule] Index ready: '
          '${index.byStop.length} stops, ${index.trips.length} trips, '
          '${index.tripStops.length} tripStops, '
          '${index.freqs.length} freq trips');

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

  // ── Arrivals ──────────────────────────────────────────────────────────────

  static Future<List<GtfsArrival>> getArrivals(
    String stopId, {
    int windowMinutes = 90,
  }) async {
    final index = await _load();
    final now = DateTime.now();
    final nowSecs = now.hour * 3600 + now.minute * 60 + now.second;
    final limitSecs = nowSecs + windowMinutes * 60;
    final dateStr = _dateStr(now);
    final dayIdx = now.weekday - 1;

    final times = index.byStop[stopId];
    if (times == null || times.isEmpty) return [];

    var result = _collectArrivals(times, nowSecs, limitSecs, index,
        dateStr, dayIdx, strict: true);
    if (result.isEmpty) {
      result = _collectArrivals(times, nowSecs, limitSecs, index,
          dateStr, dayIdx, strict: false);
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

    for (final st in times) {
      final trip = index.trips[st.tripId];
      if (trip == null) continue;

      final runs = strict
          ? _serviceRunsStrict(trip.serviceId, dateStr, dayIdx,
              index.calendar, index.caldates)
          : _serviceRunsDayOnly(trip.serviceId, dayIdx, index.calendar);
      if (!runs) continue;

      final freqList = index.freqs[st.tripId];

      if (freqList != null && freqList.isNotEmpty) {
        final base = index.tripBaseTimes[st.tripId] ?? st.arrivalSecs;
        final offsetSecs = st.arrivalSecs - base;
        for (final freq in freqList) {
          int tripDep = freq.startSecs;
          while (tripDep + offsetSecs <= freq.endSecs) {
            final actualSecs = tripDep + offsetSecs;
            if (actualSecs >= nowSecs && actualSecs <= limitSecs) {
              routeTimes.putIfAbsent(trip.routeId, () => []).add(actualSecs);
              routeHead[trip.routeId] ??= trip.headsign;
            }
            tripDep += freq.headwaySecs;
            if (freq.headwaySecs <= 0) break;
          }
        }
      } else {
        if (st.arrivalSecs >= nowSecs && st.arrivalSecs <= limitSecs) {
          routeTimes.putIfAbsent(trip.routeId, () => []).add(st.arrivalSecs);
          routeHead[trip.routeId] ??= trip.headsign;
        }
      }
    }

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

  // ── Route detail ──────────────────────────────────────────────────────────

  /// Returns full route info for showing the stop list timeline.
  /// [routeShortName] matches [GtfsArrival.routeId].
  static Future<RouteDetail?> getRouteDetail(
    String stopId,
    String routeShortName, {
    int directionId = 0,
  }) async {
    final index = await _load();
    final now = DateTime.now();
    final nowSecs = now.hour * 3600 + now.minute * 60 + now.second;
    final dayIdx = now.weekday - 1;

    final stopTimes = index.byStop[stopId];
    if (stopTimes == null || stopTimes.isEmpty) return null;

    // Collect all times at this stop for the route+direction,
    // and find a representative trip (most stops).
    final allTimeSecs = <int>{};
    String? headsign;
    String? routeId;
    String? repTripId;
    int repTripLen = 0;

    for (final st in stopTimes) {
      final trip = index.trips[st.tripId];
      if (trip == null) continue;
      final sn = index.routeNames[trip.routeId] ?? trip.routeId;
      if (sn != routeShortName) continue;
      if (trip.directionId != directionId) continue;

      routeId = trip.routeId;
      headsign ??= trip.headsign;

      // Use day-of-week only to handle stale GTFS dates
      if (_serviceRunsDayOnly(trip.serviceId, dayIdx, index.calendar)) {
        final freqList = index.freqs[st.tripId];
        if (freqList != null && freqList.isNotEmpty) {
          final base = index.tripBaseTimes[st.tripId] ?? st.arrivalSecs;
          final offset = st.arrivalSecs - base;
          for (final freq in freqList) {
            int dep = freq.startSecs;
            while (dep + offset <= freq.endSecs) {
              allTimeSecs.add(dep + offset);
              dep += freq.headwaySecs;
              if (freq.headwaySecs <= 0) break;
            }
          }
        } else {
          allTimeSecs.add(st.arrivalSecs);
        }
      }

      // Pick the trip that serves the most stops
      final len = index.tripStops[st.tripId]?.length ?? 0;
      if (len > repTripLen) {
        repTripLen = len;
        repTripId = st.tripId;
      }
    }

    // If no results for this direction, try the other direction
    if (routeId == null) {
      final otherDir = 1 - directionId;
      for (final st in stopTimes) {
        final trip = index.trips[st.tripId];
        if (trip == null) continue;
        final sn = index.routeNames[trip.routeId] ?? trip.routeId;
        if (sn != routeShortName) continue;
        if (trip.directionId != otherDir) continue;
        routeId = trip.routeId;
        headsign ??= trip.headsign;
        final len = index.tripStops[st.tripId]?.length ?? 0;
        if (len > repTripLen) {
          repTripLen = len;
          repTripId = st.tripId;
        }
      }
      if (routeId != null) directionId = otherDir;
    }

    if (routeId == null || repTripId == null) return null;

    // Build ordered stop list for the representative trip
    final rawStops = List<_TripStop>.from(index.tripStops[repTripId] ?? []);
    rawStops.sort((a, b) => a.seq.compareTo(b.seq));
    final stops = rawStops
        .map((s) => RouteStopItem(
              stopId: s.stopId,
              stopName: index.stopNames[s.stopId] ?? s.stopId,
            ))
        .toList();

    final currentStopIndex = stops.indexWhere((s) => s.stopId == stopId);

    // Sort + deduplicate times
    final sortedTimes = allTimeSecs.toList()..sort();

    // Format "HH:MM am/pm"
    String secsToStr(int secs) {
      final h = (secs ~/ 3600) % 24;
      final m = (secs % 3600) ~/ 60;
      final period = h < 12 ? 'am' : 'pm';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
    }

    final scheduledTimes = sortedTimes.map(secsToStr).toList();

    int? nextSecs;
    for (final t in sortedTimes) {
      if (t >= nowSecs) { nextSecs = t; break; }
    }

    // Check if other direction exists
    final hasOther = index.trips.values
        .any((t) => t.routeId == routeId && t.directionId == (1 - directionId));

    return RouteDetail(
      routeShortName: routeShortName,
      headsign: headsign ?? routeShortName,
      directionId: directionId,
      hasOtherDirection: hasOther,
      stops: stops,
      currentStopIndex: currentStopIndex,
      allScheduledTimes: scheduledTimes,
      nextDepartureStr: nextSecs != null ? secsToStr(nextSecs) : null,
    );
  }

  // ── Calendar helpers ──────────────────────────────────────────────────────

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

// ── Isolate parser ────────────────────────────────────────────────────────────

_GtfsScheduleIndex _parseScheduleInIsolate(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);

  String? stopsCsv, routesCsv, tripsCsv, calCsv, calDatesCsv,
      stopTimesCsv, freqCsv;

  for (final f in archive) {
    if (!f.isFile) continue;
    final name = f.name.split('/').last.toLowerCase();
    switch (name) {
      case 'stops.txt':
        stopsCsv = String.fromCharCodes(f.content as List<int>);
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

  // ── stops.txt ─────────────────────────────────────────────────────────────
  final stopNames = <String, String>{};
  if (stopsCsv != null) {
    final lines = stopsCsv.split('\n');
    if (lines.isNotEmpty) {
      final h = _header(lines[0]);
      final iId = h['stop_id'] ?? -1;
      final iName = h['stop_name'] ?? -1;
      for (int i = 1; i < lines.length; i++) {
        final c = _csvSplit(lines[i]);
        if (c.isEmpty) continue;
        final id = _cell(c, iId);
        final name = _cell(c, iName);
        if (id.isNotEmpty && name.isNotEmpty) stopNames[id] = name;
      }
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
      final iDir = h['direction_id'] ?? -1;
      for (int i = 1; i < lines.length; i++) {
        final c = _csvSplit(lines[i]);
        if (c.isEmpty) continue;
        final tripId = _cell(c, iTrip);
        if (tripId.isEmpty) continue;
        trips[tripId] = _Trip(
          _cell(c, iRoute),
          _cell(c, iService),
          _cell(c, iHead),
          int.tryParse(_cell(c, iDir)) ?? 0,
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
  final byStop = <String, List<_StopTime>>{};
  final tripStops = <String, List<_TripStop>>{};
  final tripBaseTimes = <String, int>{};

  if (stopTimesCsv != null) {
    final lines = stopTimesCsv.split('\n');
    if (lines.isNotEmpty) {
      final h = _header(lines[0]);
      final iTrip = h['trip_id'] ?? -1;
      final iArrival = h['arrival_time'] ?? -1;
      final iStopId = h['stop_id'] ?? -1;
      final iSeq = h['stop_sequence'] ?? -1;

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

        final seq = int.tryParse(_cell(c, iSeq)) ?? 0;

        byStop.putIfAbsent(stopId, () => []).add(_StopTime(tripId, arrSecs));
        tripStops.putIfAbsent(tripId, () => []).add(_TripStop(stopId, seq));

        final existing = tripBaseTimes[tripId];
        if (existing == null || arrSecs < existing) {
          tripBaseTimes[tripId] = arrSecs;
        }
      }
    }
  }

  return _GtfsScheduleIndex(
    byStop: byStop,
    tripStops: tripStops,
    stopNames: stopNames,
    trips: trips,
    routeNames: routeNames,
    calendar: calendar,
    caldates: caldates,
    freqs: freqs,
    tripBaseTimes: tripBaseTimes,
  );
}

// ── CSV helpers ───────────────────────────────────────────────────────────────

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
