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
  final int routeType;
  final String color; // hex WITHOUT #

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
  final int arrivalSecs;
  final int departureSecs;
  final int sequence;

  const GtfsStopTime({
    required this.stopId,
    required this.arrivalSecs,
    required this.departureSecs,
    required this.sequence,
  });
}

/// One frequency band: run trip repeatedly from [startSecs] to [endSecs]
/// with [headwaySecs] between each departure.
class GtfsFrequency {
  final int startSecs;
  final int endSecs;
  final int headwaySecs;

  const GtfsFrequency({
    required this.startSecs,
    required this.endSecs,
    required this.headwaySecs,
  });
}

/// An estimated vehicle position derived from the GTFS timetable.
class ScheduledVehicle {
  final String tripId;
  final String routeId;
  final String routeShortName;
  final String routeLongName;
  final String routeColor;
  final int directionId;
  final String headsign;
  final String prevStopName;
  final String nextStopName;
  final double lat;
  final double lng;
  final double bearing;
  final double progressFraction;
  final bool isAtStop;
  final int secondsUntilNextStop;
  final bool isUpcoming;
  final int secondsUntilDeparture;

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
    this.isUpcoming = false,
    this.secondsUntilDeparture = 0,
  });

  String get locationLabel {
    if (isUpcoming) return 'Departs from $prevStopName';
    if (isAtStop)   return 'At $prevStopName';
    return '$prevStopName → $nextStopName';
  }

  String get minutesToNext {
    if (isUpcoming) {
      final m = (secondsUntilDeparture / 60).ceil();
      if (m <= 0) return 'now';
      if (m == 1) return 'in 1 min';
      return 'in $m min';
    }
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
  final Map<String, List<GtfsFrequency>> freqsByTrip; // NEW
  final Set<String> activeServiceIds;
  final int totalTrips;
  final int totalStopTimes;

  const ParsedSchedule({
    required this.routes,
    required this.stops,
    required this.trips,
    required this.stopTimesByTrip,
    required this.freqsByTrip,
    required this.activeServiceIds,
    required this.totalTrips,
    required this.totalStopTimes,
  });

  /// Estimates active + upcoming vehicles at [now].
  /// Correctly handles GTFS frequency-based schedules.
  List<ScheduledVehicle> computeAtTime(DateTime now, {int lookAheadSecs = 3600}) {
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

      final trip = trips[tid];
      if (trip == null) continue;
      if (activeServiceIds.isNotEmpty &&
          !activeServiceIds.contains(trip.serviceId)) continue;

      final route = routes[trip.routeId];
      if (route == null) continue;

      // Template offset: all stop times are relative to the template's first departure
      final templateFirstDep = times.first.departureSecs;
      final tripDuration     = times.last.arrivalSecs - templateFirstDep;

      final freqs = freqsByTrip[tid];

      if (freqs != null && freqs.isNotEmpty) {
        // ── Frequency-based trip ─────────────────────────────────────────────
        for (final freq in freqs) {
          final bandStart = freq.startSecs;
          final bandEnd   = freq.endSecs;
          final headway   = freq.headwaySecs;
          if (headway <= 0) continue;

          // Earliest instance that could still be running (or upcoming)
          final firstRunningK = nowSecs > bandStart + tripDuration
              ? ((nowSecs - bandStart - tripDuration) / headway).floor()
              : 0;

          int k = firstRunningK < 0 ? 0 : firstRunningK;

          while (true) {
            final instanceDep = bandStart + k * headway;
            if (instanceDep >= bandEnd) break;            // past band end
            if (instanceDep > nowSecs + lookAheadSecs) break; // beyond lookahead

            final instanceEnd = instanceDep + tripDuration;

            if (instanceEnd < nowSecs) { k++; continue; } // already finished

            if (instanceDep > nowSecs) {
              // ── Upcoming ──────────────────────────────────────────────────
              final firstStop  = stops[times.first.stopId];
              final secondStop = times.length > 1 ? stops[times[1].stopId] : null;
              if (firstStop == null) { k++; continue; }
              result.add(ScheduledVehicle(
                tripId:              '$tid#$k',
                routeId:             trip.routeId,
                routeShortName:      route.shortName.isNotEmpty ? route.shortName : route.routeId,
                routeLongName:       route.longName,
                routeColor:          route.color,
                directionId:         trip.directionId,
                headsign:            trip.headsign,
                prevStopName:        firstStop.stopName,
                nextStopName:        secondStop?.stopName ?? firstStop.stopName,
                lat:                 firstStop.lat,
                lng:                 firstStop.lng,
                bearing:             secondStop != null
                    ? _bearing(firstStop.lat, firstStop.lng,
                               secondStop.lat, secondStop.lng)
                    : 0,
                progressFraction:    0,
                isAtStop:            true,
                secondsUntilNextStop: instanceDep - nowSecs,
                isUpcoming:          true,
                secondsUntilDeparture: instanceDep - nowSecs,
              ));
            } else {
              // ── Currently running ─────────────────────────────────────────
              final offsetSecs = nowSecs - instanceDep; // how far into this trip

              // Find the segment the train is in
              int segIdx = -1;
              for (int i = 0; i < times.length - 1; i++) {
                final segDepOff = times[i].departureSecs - templateFirstDep;
                final segArrOff = times[i + 1].arrivalSecs - templateFirstDep;
                if (offsetSecs >= segDepOff && offsetSecs <= segArrOff) {
                  segIdx = i;
                  break;
                }
              }
              if (segIdx < 0) { k++; continue; }

              final prev = stops[times[segIdx].stopId];
              final next = stops[times[segIdx + 1].stopId];
              if (prev == null || next == null) { k++; continue; }

              final segDepOff = times[segIdx].departureSecs     - templateFirstDep;
              final segArrOff = times[segIdx + 1].arrivalSecs   - templateFirstDep;
              final segDur    = segArrOff - segDepOff;
              final fraction  = segDur > 0
                  ? ((offsetSecs - segDepOff) / segDur).clamp(0.0, 1.0)
                  : 0.0;

              final lat     = prev.lat + (next.lat - prev.lat) * fraction;
              final lng     = prev.lng + (next.lng - prev.lng) * fraction;
              final bearing = _bearing(prev.lat, prev.lng, next.lat, next.lng);
              final secsToNext = (instanceDep + segArrOff - nowSecs).clamp(0, segDur);

              result.add(ScheduledVehicle(
                tripId:              '$tid#$k',
                routeId:             trip.routeId,
                routeShortName:      route.shortName.isNotEmpty ? route.shortName : route.routeId,
                routeLongName:       route.longName,
                routeColor:          route.color,
                directionId:         trip.directionId,
                headsign:            trip.headsign,
                prevStopName:        prev.stopName,
                nextStopName:        next.stopName,
                lat:                 lat,
                lng:                 lng,
                bearing:             bearing,
                progressFraction:    fraction,
                isAtStop:            fraction < 0.05,
                secondsUntilNextStop: secsToNext,
              ));
            }
            k++;
          }
        }
      } else {
        // ── Non-frequency trip (original logic) ──────────────────────────────
        final firstDep = times.first.departureSecs;
        final lastArr  = times.last.arrivalSecs;
        if (nowSecs > lastArr) continue;
        if (nowSecs + lookAheadSecs < firstDep) continue;

        if (nowSecs < firstDep) {
          final firstStop  = stops[times.first.stopId];
          final secondStop = times.length > 1 ? stops[times[1].stopId] : null;
          if (firstStop == null) continue;
          result.add(ScheduledVehicle(
            tripId:              tid,
            routeId:             trip.routeId,
            routeShortName:      route.shortName.isNotEmpty ? route.shortName : route.routeId,
            routeLongName:       route.longName,
            routeColor:          route.color,
            directionId:         trip.directionId,
            headsign:            trip.headsign,
            prevStopName:        firstStop.stopName,
            nextStopName:        secondStop?.stopName ?? firstStop.stopName,
            lat:                 firstStop.lat,
            lng:                 firstStop.lng,
            bearing:             secondStop != null
                ? _bearing(firstStop.lat, firstStop.lng,
                           secondStop.lat, secondStop.lng)
                : 0,
            progressFraction:    0,
            isAtStop:            true,
            secondsUntilNextStop: firstDep - nowSecs,
            isUpcoming:          true,
            secondsUntilDeparture: firstDep - nowSecs,
          ));
        } else {
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
          final fraction = segDur > 0
              ? ((nowSecs - segStart) / segDur).clamp(0.0, 1.0)
              : 0.0;

          result.add(ScheduledVehicle(
            tripId:              tid,
            routeId:             trip.routeId,
            routeShortName:      route.shortName.isNotEmpty ? route.shortName : route.routeId,
            routeLongName:       route.longName,
            routeColor:          route.color,
            directionId:         trip.directionId,
            headsign:            trip.headsign,
            prevStopName:        prev.stopName,
            nextStopName:        next.stopName,
            lat:                 prev.lat + (next.lat - prev.lat) * fraction,
            lng:                 prev.lng + (next.lng - prev.lng) * fraction,
            bearing:             _bearing(prev.lat, prev.lng, next.lat, next.lng),
            progressFraction:    fraction,
            isAtStop:            fraction < 0.05,
            secondsUntilNextStop: (segEnd - nowSecs).clamp(0, segDur),
          ));
        }
      }
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

ParsedSchedule _parseGtfsInIsolate(Map<String, dynamic> params) {
  final bytes    = params['bytes'] as Uint8List;
  final todayStr = params['today'] as String;

  // ── Extract files from ZIP ────────────────────────────────────────────────
  // Prasarana ZIP may have sub-folders per operator; concatenate same-name files.
  final archive = ZipDecoder().decodeBytes(bytes);
  String? routesCsv, stopsCsv, tripsCsv, stTimesCsv, calCsv, calDatesCsv, freqsCsv;

  // Strip UTF-8 BOM (\uFEFF) that some files include
  String stripBom(String s) => s.startsWith('\uFEFF') ? s.substring(1) : s;

  // Append CSV content, skipping the header of subsequent files
  String appendCsv(String? existing, String incoming) {
    final clean = stripBom(incoming);
    if (existing == null) return clean;
    final nl = clean.indexOf('\n');
    if (nl < 0) return existing;
    return '$existing\n${clean.substring(nl + 1)}';
  }

  for (final file in archive) {
    if (!file.isFile) continue;
    final name    = file.name.split('/').last;
    final content = utf8.decode(file.content as List<int>, allowMalformed: true);
    switch (name) {
      case 'routes.txt':         routesCsv  = appendCsv(routesCsv,  content); break;
      case 'stops.txt':          stopsCsv   = appendCsv(stopsCsv,   content); break;
      case 'trips.txt':          tripsCsv   = appendCsv(tripsCsv,   content); break;
      case 'stop_times.txt':     stTimesCsv = appendCsv(stTimesCsv, content); break;
      case 'calendar.txt':       calCsv     = appendCsv(calCsv,     content); break;
      case 'calendar_dates.txt': calDatesCsv = appendCsv(calDatesCsv, content); break;
      case 'frequencies.txt':    freqsCsv   = appendCsv(freqsCsv,   content); break;
    }
  }

  if (routesCsv == null || stopsCsv == null ||
      tripsCsv == null || stTimesCsv == null) {
    throw Exception('Required GTFS files missing from ZIP');
  }

  // ── CSV helpers ───────────────────────────────────────────────────────────

  List<String> csvSplit(String line) {
    final fields = <String>[];
    final buf = StringBuffer();
    bool inQ = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"')           { inQ = !inQ; continue; }
      if (c == ',' && !inQ)  { fields.add(buf.toString()); buf.clear(); continue; }
      buf.write(c);
    }
    fields.add(buf.toString());
    return fields;
  }

  Map<String, int> colIdx(String header) {
    final idx  = <String, int>{};
    final cols = csvSplit(stripBom(header).trimRight());
    for (int i = 0; i < cols.length; i++) idx[cols[i].trim()] = i;
    return idx;
  }

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

  // ── Calendar → today's active service IDs ────────────────────────────────
  final activeServiceIds = <String>{};
  {
    final y  = int.parse(todayStr.substring(0, 4));
    final mo = int.parse(todayStr.substring(4, 6));
    final d  = int.parse(todayStr.substring(6, 8));
    final weekday = DateTime(y, mo, d).weekday; // 1=Mon, 7=Sun
    const dayNames = [
      'monday','tuesday','wednesday','thursday','friday','saturday','sunday'
    ];
    final dayCol = dayNames[weekday - 1];

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

  // Fallback: if calendar has no active services (expired), accept all
  final bool skipServiceFilter = activeServiceIds.isEmpty;

  // ── Parse trips.txt ───────────────────────────────────────────────────────
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
        if (!skipServiceFilter && !activeServiceIds.contains(sid)) continue;
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

  // ── Parse frequencies.txt ─────────────────────────────────────────────────
  final freqsByTrip = <String, List<GtfsFrequency>>{};
  if (freqsCsv != null && freqsCsv.isNotEmpty) {
    final lines = freqsCsv.split('\n');
    if (lines.isNotEmpty) {
      final idx = colIdx(lines[0]);
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.isEmpty) continue;
        final c   = csvSplit(line);
        final tid = cell(c, idx['trip_id']);
        if (!activeTripIds.contains(tid)) continue;
        final start   = parseSecs(cell(c, idx['start_time']));
        final end     = parseSecs(cell(c, idx['end_time']));
        final headway = int.tryParse(cell(c, idx['headway_secs'])) ?? 0;
        if (start < 0 || end < 0 || headway <= 0) continue;
        freqsByTrip.putIfAbsent(tid, () => []).add(GtfsFrequency(
          startSecs:   start,
          endSecs:     end,
          headwaySecs: headway,
        ));
      }
    }
  }

  // ── Parse stop_times.txt ──────────────────────────────────────────────────
  final rawStopTimes = <String, List<GtfsStopTime>>{};
  int totalSt = 0;
  {
    final lines = stTimesCsv.split('\n');
    if (lines.isNotEmpty) {
      final idx     = colIdx(lines[0]);
      final cidTrip = idx['trip_id'];
      final cidArr  = idx['arrival_time'];
      final cidDep  = idx['departure_time'];
      final cidStop = idx['stop_id'];
      final cidSeq  = idx['stop_sequence'];

      if (cidTrip != null && cidStop != null && cidSeq != null) {
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trimRight();
          if (line.isEmpty) continue;
          final c   = csvSplit(line);
          final tid = cell(c, cidTrip);
          if (!activeTripIds.contains(tid)) continue;

          final depStr = cidDep != null ? cell(c, cidDep) : '';
          final arrStr = cidArr != null ? cell(c, cidArr) : '';
          final dep    = depStr.isNotEmpty ? parseSecs(depStr) : parseSecs(arrStr);
          final arr    = arrStr.isNotEmpty ? parseSecs(arrStr) : dep;
          if (dep < 0 || arr < 0) continue;

          rawStopTimes.putIfAbsent(tid, () => []).add(GtfsStopTime(
            stopId:        cell(c, cidStop),
            arrivalSecs:   arr,
            departureSecs: dep,
            sequence:      int.tryParse(cell(c, cidSeq)) ?? 0,
          ));
          totalSt++;
        }
      }
    }
    for (final list in rawStopTimes.values) {
      list.sort((a, b) => a.sequence.compareTo(b.sequence));
    }
  }

  return ParsedSchedule(
    routes:          routes,
    stops:           stops,
    trips:           trips,
    stopTimesByTrip: rawStopTimes,
    freqsByTrip:     freqsByTrip,
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
  static String?         _cacheDate;
  static Completer<ParsedSchedule>? _inFlight;

  static bool get isLoaded        => _cached != null;
  static int  get cachedTripCount => _cached?.totalTrips ?? 0;

  static String _serviceDay() {
    final now = DateTime.now();
    final d   = now.hour < 3 ? now.subtract(const Duration(days: 1)) : now;
    return '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
  }

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

  static List<ScheduledVehicle> computeCurrentVehicles() {
    if (_cached == null) return [];
    return _cached!.computeAtTime(DateTime.now());
  }

  /// Returns all unique [GtfsStop]s served by trips on any of [routeIds].
  static List<GtfsStop> stopsForRoutes(List<String> routeIds) {
    final cache = _cached;
    if (cache == null) return [];
    final seen = <String>{};
    final result = <GtfsStop>[];
    for (final trip in cache.trips.values) {
      if (!routeIds.contains(trip.routeId)) continue;
      final times = cache.stopTimesByTrip[trip.tripId];
      if (times == null) continue;
      for (final st in times) {
        if (seen.add(st.stopId)) {
          final stop = cache.stops[st.stopId];
          if (stop != null) result.add(stop);
        }
      }
    }
    return result;
  }

  /// Seconds until the next train arrives at [stopId] for any trip on [routeIds].
  /// Returns null if no upcoming service found within 2 hours.
  static int? nextArrivalSecsAtStop(String stopId, List<String> routeIds, {DateTime? now}) {
    final cache = _cached;
    if (cache == null) return null;
    final effectiveNow = now ?? DateTime.now();
    final serviceDay = effectiveNow.hour < 3
        ? effectiveNow.subtract(const Duration(days: 1))
        : effectiveNow;
    final dayStart = DateTime(serviceDay.year, serviceDay.month, serviceDay.day);
    final nowSecs = effectiveNow.difference(dayStart).inSeconds;

    int? best;

    for (final tripEntry in cache.trips.entries) {
      final trip = tripEntry.value;
      if (!routeIds.contains(trip.routeId)) continue;
      if (cache.activeServiceIds.isNotEmpty &&
          !cache.activeServiceIds.contains(trip.serviceId)) continue;

      final tid = tripEntry.key;
      final times = cache.stopTimesByTrip[tid];
      if (times == null || times.isEmpty) continue;

      // Find this stop's index in the template
      GtfsStopTime? stEntry;
      for (final st in times) {
        if (st.stopId == stopId) { stEntry = st; break; }
      }
      if (stEntry == null) continue;

      final templateFirstDep = times.first.departureSecs;
      final stopOffset = stEntry.arrivalSecs - templateFirstDep;

      final freqs = cache.freqsByTrip[tid];
      if (freqs != null && freqs.isNotEmpty) {
        for (final freq in freqs) {
          if (freq.headwaySecs <= 0) continue;
          final rawK = (nowSecs - freq.startSecs - stopOffset) / freq.headwaySecs;
          final k = rawK < 0 ? 0 : rawK.floor() + 1;
          final instanceDep = freq.startSecs + k * freq.headwaySecs;
          if (instanceDep >= freq.endSecs) continue;
          final arrivalSecs = instanceDep + stopOffset;
          final secsUntil = arrivalSecs - nowSecs;
          if (secsUntil >= 0 && secsUntil <= 7200) {
            if (best == null || secsUntil < best) best = secsUntil;
          }
        }
      } else {
        final arrSecs = stEntry.arrivalSecs;
        final secsUntil = arrSecs - nowSecs;
        if (secsUntil >= 0 && secsUntil <= 7200) {
          if (best == null || secsUntil < best) best = secsUntil;
        }
      }
    }
    return best;
  }

  static void clearCache() {
    _cached    = null;
    _cacheDate = null;
  }
}
