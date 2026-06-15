import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── Models ────────────────────────────────────────────────────────────────────

class GtfsRoute {
  final String routeId;
  final String shortName;
  final String longName;
  final int routeType; // 0=tram, 1=metro, 2=rail, 3=bus
  final String color;  // hex WITHOUT #, e.g. "E32026"; may be empty

  const GtfsRoute({
    required this.routeId,
    required this.shortName,
    required this.longName,
    required this.routeType,
    required this.color,
  });
}

class GtfsStop {
  final String stopId;
  final String stopName;
  final double lat;
  final double lng;

  const GtfsStop({
    required this.stopId,
    required this.stopName,
    required this.lat,
    required this.lng,
  });
}

class GtfsTrip {
  final String tripId;
  final String routeId;
  final String serviceId;
  final String headsign;
  final int directionId;

  const GtfsTrip({
    required this.tripId,
    required this.routeId,
    required this.serviceId,
    required this.headsign,
    required this.directionId,
  });
}

class GtfsStopTime {
  final String stopId;
  final int arrivalSecs;    // total seconds from midnight (can exceed 86400)
  final int departureSecs;
  final int sequence;

  const GtfsStopTime({
    required this.stopId,
    required this.arrivalSecs,
    required this.departureSecs,
    required this.sequence,
  });
}

/// An estimated vehicle position derived from the GTFS timetable.
class ScheduledVehicle {
  final String tripId;
  final String routeId;
  final String routeShortName;
  final String routeLongName;
  final String routeColor; // hex without #
  final int directionId;
  final String headsign;
  final String prevStopName;
  final String nextStopName;
  final double lat;
  final double lng;
  final double bearing;       // degrees 0–360
  final double progressFraction; // 0.0–1.0 within current segment
  final bool isAtStop;
  final int secondsUntilNextStop;

  const ScheduledVehicle({
    required this.tripId,
    required this.routeId,
    required this.routeShortName,
    required this.routeLongName,
    required this.routeColor,
    required this.directionId,
    required this.headsign,
    required this.prevStopName,
    required this.nextStopName,
    required this.lat,
    required this.lng,
    required this.bearing,
    required this.progressFraction,
    required this.isAtStop,
    required this.secondsUntilNextStop,
  });

  String get locationLabel => isAtStop
      ? 'At $prevStopName'
      : '$prevStopName → $nextStopName';

  String get minutesToNext {
    final m = (secondsUntilNextStop / 60).ceil();
    if (m <= 0) return 'arriving';
    if (m == 1) return '~1 min';
    return '~$m min';
  }
}

/// The fully-parsed schedule. Lives in memory after first download.
class ParsedSchedule {
  final Map<String, GtfsRoute> routes;
  final Map<String, GtfsStop> stops;
  final Map<String, GtfsTrip> trips;
  final Map<String, List<GtfsStopTime>> stopTimesByTrip;
  final Set<String> activeServiceIds;
  final int totalTrips;      // for diagnostics
  final int totalStopTimes;

  const ParsedSchedule({
    required this.routes,
    required this.stops,
    required this.trips,
    required this.stopTimesByTrip,
    required this.activeServiceIds,
    required this.totalTrips,
    required this.totalStopTimes,
  });

  /// Estimates active vehicles at [now]. Fast – O(active trips).
  List<ScheduledVehicle> computeAtTime(DateTime now) {
    // Service day: trips after midnight belong to the previous service day
    final serviceDay = now.hour < 3
        ? now.subtract(const Duration(days: 1))
        : now;
    final dayStart = DateTime(serviceDay.year, serviceDay.month, serviceDay.day);
    final nowSecs  = now.difference(dayStart).inSeconds;

    final result = <ScheduledVehicle>[];

    for (final entry in stopTimesByTrip.entries) {
      final tid   = entry.key;
      final times = entry.value;
      if (times.length < 2) continue;

      final trip  = trips[tid];
      if (trip == null) continue;
      if (!activeServiceIds.contains(trip.serviceId)) continue;

      final route = routes[trip.routeId];
      if (route == null) continue;

      final firstDep = times.first.departureSecs;
      final lastArr  = times.last.arrivalSecs;
      if (nowSecs < firstDep || nowSecs > lastArr) continue;

      // Find which segment the train is in
      int segIdx = -1;
      for (int i = 0; i < times.length - 1; i++) {
        if (nowSecs >= times[i].departureSecs &&
            nowSecs <= times[i + 1].arrivalSecs) {
          segIdx = i;
          break;
        }
      }
      if (segIdx < 0) continue;

      final prev = stops[times[segIdx].stopId];
      final next = stops[times[segIdx + 1].stopId];
      if (prev == null || next == null) continue;

      final segStart = times[segIdx].departureSecs;
      final segEnd   = times[segIdx + 1].arrivalSecs;
      final segDur   = segEnd - segStart;
      final elapsed  = nowSecs - segStart;
      final fraction = segDur > 0
          ? (elapsed / segDur).clamp(0.0, 1.0)
          : 0.0;

      final lat     = prev.lat + (next.lat - prev.lat) * fraction;
      final lng     = prev.lng + (next.lng - prev.lng) * fraction;
      final bearing = _bearing(prev.lat, prev.lng, next.lat, next.lng);

      result.add(ScheduledVehicle(
        tripId: tid,
        routeId: trip.routeId,
        routeShortName: route.shortName.isNotEmpty ? route.shortName : route.routeId,
        routeLongName: route.longName,
        routeColor: route.color,
        directionId: trip.directionId,
        headsign: trip.headsign,
        prevStopName: prev.stopName,
        nextStopName: next.stopName,
        lat: lat,
        lng: lng,
        bearing: bearing,
        progressFraction: fraction,
        isAtStop: fraction < 0.05,
        secondsUntilNextStop: (segEnd - nowSecs).clamp(0, segDur),
      ));
    }

    return result;
  }

  static double _bearing(double lat1, double lng1, double lat2, double lng2) {
    final lat1r = lat1 * pi / 180;
    final lat2r = lat2 * pi / 180;
    final dlng  = (lng2 - lng1) * pi / 180;
    final x = sin(dlng) * cos(lat2r);
    final y = cos(lat1r) * sin(lat2r) - sin(lat1r) * cos(lat2r) * cos(dlng);
    return (atan2(x, y) * 180 / pi + 360) % 360;
  }
}

// ── Isolate entry point ───────────────────────────────────────────────────────
// Must be a top-level function for compute().

ParsedSchedule _parseGtfsInIsolate(Map<String, dynamic> params) {
  final bytes    = params['bytes'] as Uint8List;
  final todayStr = params['today'] as String;

  // ── Extract files from ZIP ────────────────────────────────────────────────
  final archive = ZipDecoder().decodeBytes(bytes);
  String? routesCsv, stopsCsv, tripsCsv, stTimesCsv, calCsv, calDatesCsv;

  for (final file in archive) {
    if (!file.isFile) continue;
    // Strip leading directories (some ZIPs nest files)
    final name = file.name.split('/').last;
    final decode = () => utf8.decode(file.content as List<int>, allowMalformed: true);
    switch (name) {
      case 'routes.txt':         routesCsv    = decode(); break;
      case 'stops.txt':          stopsCsv     = decode(); break;
      case 'trips.txt':          tripsCsv     = decode(); break;
      case 'stop_times.txt':     stTimesCsv   = decode(); break;
      case 'calendar.txt':       calCsv       = decode(); break;
      case 'calendar_dates.txt': calDatesCsv  = decode(); break;
    }
  }

  if (routesCsv == null || stopsCsv == null ||
      tripsCsv == null || stTimesCsv == null) {
    throw Exception('Required GTFS files missing from ZIP');
  }

  // ── CSV helpers ───────────────────────────────────────────────────────────

  // Quote-aware CSV split
  List<String> csvSplit(String line) {
    final fields = <String>[];
    final buf = StringBuffer();
    bool inQ = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"')      { inQ = !inQ; continue; }
      if (c == ',' && !inQ) { fields.add(buf.toString()); buf.clear(); continue; }
      buf.write(c);
    }
    fields.add(buf.toString());
    return fields;
  }

  Map<String, int> colIdx(String header) {
    final idx = <String, int>{};
    final cols = csvSplit(header.trimRight());
    for (int i = 0; i < cols.length; i++) idx[cols[i].trim()] = i;
    return idx;
  }

  // GTFS time "HH:MM:SS" → total seconds (hours can be > 24)
  int parseSecs(String t) {
    final p = t.trim().split(':');
    if (p.length != 3) return -1;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final s = int.tryParse(p[2]);
    if (h == null || m == null || s == null) return -1;
    return h * 3600 + m * 60 + s;
  }

  String cell(List<String> cols, int? i) =>
      i != null && i < cols.length ? cols[i].trim() : '';

  // ── Parse routes.txt ─────────────────────────────────────────────────────
  final routes = <String, GtfsRoute>{};
  {
    final lines = routesCsv.split('\n');
    if (lines.isNotEmpty) {
      final idx = colIdx(lines[0]);
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final c   = csvSplit(line);
        final rid = cell(c, idx['route_id']);
        if (rid.isEmpty) continue;
        routes[rid] = GtfsRoute(
          routeId:   rid,
          shortName: cell(c, idx['route_short_name']),
          longName:  cell(c, idx['route_long_name']),
          routeType: int.tryParse(cell(c, idx['route_type'])) ?? 1,
          color:     cell(c, idx['route_color']),
        );
      }
    }
  }

  // ── Parse stops.txt ───────────────────────────────────────────────────────
  final stops = <String, GtfsStop>{};
  {
    final lines = stopsCsv.split('\n');
    if (lines.isNotEmpty) {
      final idx = colIdx(lines[0]);
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final c   = csvSplit(line);
        final sid = cell(c, idx['stop_id']);
        if (sid.isEmpty) continue;
        final lat = double.tryParse(cell(c, idx['stop_lat']));
        final lng = double.tryParse(cell(c, idx['stop_lon']));
        if (lat == null || lng == null) continue;
        stops[sid] = GtfsStop(
          stopId:   sid,
          stopName: cell(c, idx['stop_name']),
          lat:      lat,
          lng:      lng,
        );
      }
    }
  }

  // ── Calendar → today's active service IDs ─────────────────────────────────
  final activeServiceIds = <String>{};
  {
    final y = int.parse(todayStr.substring(0, 4));
    final mo = int.parse(todayStr.substring(4, 6));
    final d  = int.parse(todayStr.substring(6, 8));
    final weekday = DateTime(y, mo, d).weekday; // 1=Mon, 7=Sun
    const dayNames = [
      'monday','tuesday','wednesday','thursday','friday','saturday','sunday'
    ];
    final dayCol = dayNames[weekday - 1];

    // calendar.txt
    if (calCsv != null && calCsv.isNotEmpty) {
      final lines = calCsv.split('\n');
      if (lines.isNotEmpty) {
        final idx = colIdx(lines[0]);
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trimRight();
          if (line.isEmpty) continue;
          final c     = csvSplit(line);
          final sid   = cell(c, idx['service_id']);
          final flag  = cell(c, idx[dayCol]);
          final start = cell(c, idx['start_date']);
          final end   = cell(c, idx['end_date']);
          if (flag == '1' &&
              todayStr.compareTo(start) >= 0 &&
              todayStr.compareTo(end) <= 0) {
            activeServiceIds.add(sid);
          }
        }
      }
    }

    // calendar_dates.txt (exceptions)
    if (calDatesCsv != null && calDatesCsv.isNotEmpty) {
      final lines = calDatesCsv.split('\n');
      if (lines.isNotEmpty) {
        final idx = colIdx(lines[0]);
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trimRight();
          if (line.isEmpty) continue;
          final c    = csvSplit(line);
          final sid  = cell(c, idx['service_id']);
          final date = cell(c, idx['date']);
          final type = cell(c, idx['exception_type']);
          if (date != todayStr) continue;
          if (type == '1') activeServiceIds.add(sid);
          if (type == '2') activeServiceIds.remove(sid);
        }
      }
    }
  }

  // ── Parse trips.txt → filter by active service IDs ───────────────────────
  final trips         = <String, GtfsTrip>{};
  final activeTripIds = <String>{};
  {
    final lines = tripsCsv.split('\n');
    if (lines.isNotEmpty) {
      final idx = colIdx(lines[0]);
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final c   = csvSplit(line);
        final sid = cell(c, idx['service_id']);
        if (!activeServiceIds.contains(sid)) continue;
        final tid = cell(c, idx['trip_id']);
        if (tid.isEmpty) continue;
        final rid = cell(c, idx['route_id']);
        trips[tid] = GtfsTrip(
          tripId:      tid,
          routeId:     rid,
          serviceId:   sid,
          headsign:    cell(c, idx['trip_headsign']),
          directionId: int.tryParse(cell(c, idx['direction_id'])) ?? 0,
        );
        activeTripIds.add(tid);
      }
    }
  }

  // ── Parse stop_times.txt → filter by active trip IDs ─────────────────────
  final rawStopTimes = <String, List<GtfsStopTime>>{};
  int totalSt = 0;
  {
    final lines = stTimesCsv.split('\n');
    if (lines.isNotEmpty) {
      final idx        = colIdx(lines[0]);
      final cidTrip    = idx['trip_id'];
      final cidArr     = idx['arrival_time'];
      final cidDep     = idx['departure_time'];
      final cidStop    = idx['stop_id'];
      final cidSeq     = idx['stop_sequence'];

      if (cidTrip != null && cidStop != null && cidSeq != null) {
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trimRight();
          if (line.isEmpty) continue;

          // Fast early-exit: extract trip_id without full split when cidTrip == 0
          if (cidTrip == 0) {
            final comma = line.indexOf(',');
            if (comma >= 0 && !activeTripIds.contains(line.substring(0, comma))) {
              continue;
            }
          }

          final c   = csvSplit(line);
          final tid = cell(c, cidTrip);
          if (!activeTripIds.contains(tid)) continue;

          final depStr = cidDep != null ? cell(c, cidDep) : '';
          final arrStr = cidArr != null ? cell(c, cidArr) : '';
          final dep    = depStr.isNotEmpty ? parseSecs(depStr) : parseSecs(arrStr);
          final arr    = arrStr.isNotEmpty ? parseSecs(arrStr) : dep;
          if (dep < 0 || arr < 0) continue;

          final stopId = cell(c, cidStop);
          final seq    = int.tryParse(cell(c, cidSeq)) ?? 0;

          rawStopTimes.putIfAbsent(tid, () => []).add(GtfsStopTime(
            stopId:       stopId,
            arrivalSecs:  arr,
            departureSecs: dep,
            sequence:     seq,
          ));
          totalSt++;
        }
      }
    }
    // Sort each trip by stop sequence
    for (final list in rawStopTimes.values) {
      list.sort((a, b) => a.sequence.compareTo(b.sequence));
    }
  }

  return ParsedSchedule(
    routes:          routes,
    stops:           stops,
    trips:           trips,
    stopTimesByTrip: rawStopTimes,
    activeServiceIds: activeServiceIds,
    totalTrips:      trips.length,
    totalStopTimes:  totalSt,
  );
}

// ── Service ───────────────────────────────────────────────────────────────────

class GtfsStaticScheduleService {
  static const _url =
      'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl';

  static ParsedSchedule? _cached;
  static String? _cacheDate;
  static Completer<ParsedSchedule>? _inFlight;

  static bool get isLoaded => _cached != null;

  /// Today's service-day string "YYYYMMDD".
  /// Before 3 AM: yesterday (post-midnight trips belong to prior service day).
  static String _serviceDay() {
    final now = DateTime.now();
    final d   = now.hour < 3 ? now.subtract(const Duration(days: 1)) : now;
    return '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Downloads + parses the schedule if needed; returns from cache otherwise.
  static Future<ParsedSchedule> getSchedule() async {
    final today = _serviceDay();
    if (_cached != null && _cacheDate == today) return _cached!;
    if (_inFlight != null) return _inFlight!.future;

    final completer = Completer<ParsedSchedule>();
    _inFlight = completer;

    try {
      final resp = await http
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 90));

      if (resp.statusCode != 200) {
        throw Exception('GTFS static HTTP ${resp.statusCode}');
      }

      // Parse entirely in a background isolate (ZIP decompression + CSV parsing)
      final schedule = await compute<Map<String, dynamic>, ParsedSchedule>(
        _parseGtfsInIsolate,
        {'bytes': resp.bodyBytes, 'today': today},
      );

      _cached    = schedule;
      _cacheDate = today;
      _inFlight  = null;
      completer.complete(schedule);
      return schedule;
    } catch (e) {
      _inFlight = null;
      completer.completeError(e);
      rethrow;
    }
  }

  /// Recomputes vehicle positions right now from the in-memory schedule.
  /// Synchronous — safe to call on the main thread every 30 s.
  static List<ScheduledVehicle> computeCurrentVehicles() {
    if (_cached == null) return [];
    return _cached!.computeAtTime(DateTime.now());
  }

  /// Clears cache (for testing / manual refresh).
  static void clearCache() {
    _cached    = null;
    _cacheDate = null;
  }
}
