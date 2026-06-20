import 'dart:async';
import 'dart:ui' show Color;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ── Public models ─────────────────────────────────────────────────────────────

class RailLine {
  final String id;
  final String shortName;
  final String longName;
  final Color color;
  final List<LatLng> path; // ordered shape polyline

  const RailLine({
    required this.id,
    required this.shortName,
    required this.longName,
    required this.color,
    required this.path,
  });

  String get displayName => shortName.isNotEmpty ? shortName : longName;
}

class RailStation {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final List<String> lineIds; // routes that serve this station

  const RailStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.lineIds,
  });

  bool get isInterchange => lineIds.length > 1;
  LatLng get latLng => LatLng(lat, lng);
}

class RailNetwork {
  final List<RailLine> lines;
  final List<RailStation> stations;

  const RailNetwork({required this.lines, required this.stations});
}

// ── Service ───────────────────────────────────────────────────────────────────

class GtfsRailService {
  static const _url =
      'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl';

  static RailNetwork? _cache;
  static String? _cacheDate;
  static Completer<RailNetwork>? _inFlight;

  static String _today() {
    final now = DateTime.now();
    final d = now.hour < 3 ? now.subtract(const Duration(days: 1)) : now;
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  static bool get isLoaded => _cache != null;

  static Future<RailNetwork> getNetwork() async {
    final today = _today();
    if (_cache != null && _cacheDate == today) return _cache!;
    if (_inFlight != null) return _inFlight!.future;

    final completer = Completer<RailNetwork>();
    _inFlight = completer;

    try {
      debugPrint('[GtfsRail] Downloading rapid-rail-kl GTFS…');
      final resp = await http
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 120));

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      debugPrint('[GtfsRail] Downloaded '
          '${(resp.bodyBytes.length / 1024).round()} KB, parsing…');
      final network = await compute(_parseInIsolate, resp.bodyBytes);

      debugPrint('[GtfsRail] Network ready: '
          '${network.lines.length} lines, ${network.stations.length} stations');

      _cache = network;
      _cacheDate = today;
      _inFlight = null;
      completer.complete(network);
      return network;
    } catch (e, st) {
      _inFlight = null;
      debugPrint('[GtfsRail] Error: $e\n$st');
      completer.completeError(e);
      rethrow;
    }
  }

  static void clearCache() {
    _cache = null;
    _cacheDate = null;
  }
}

// ── Isolate parser ─────────────────────────────────────────────────────────────

// Fallback colors keyed on partial route name (lowercase)
const _fallbackColors = <String, int>{
  'kelana jaya': 0xFFEF3E36,   // KJ Line — red
  'kj':          0xFFEF3E36,
  'ampang':      0xFFE6962D,   // Ampang/SP — orange
  'sri petaling':0xFFE6962D,
  'kajang':      0xFF4DA13E,   // MRT Kajang — green
  'putrajaya':   0xFF1261AA,   // MRT Putrajaya — blue
  'monorail':    0xFF8A3791,   // Monorail — purple
  'mr':          0xFF8A3791,
  'sunway':      0xFF00A79D,   // BRT Sunway — teal
  'brt':         0xFF00A79D,
  'ktm':         0xFF2196F3,   // KTM — blue
  'erl':         0xFFE91E63,   // KLIA Ekspres — pink
  'klia':        0xFFE91E63,
};

const _defaultColor = 0xFF607D8B; // blue-grey fallback

RailNetwork _parseInIsolate(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);

  String? routesCsv, tripsCsv, shapesCsv, stopsCsv, stopTimesCsv;
  for (final f in archive) {
    if (!f.isFile) continue;
    final name = f.name.split('/').last.toLowerCase();
    switch (name) {
      case 'routes.txt':    routesCsv   = String.fromCharCodes(f.content as List<int>);
      case 'trips.txt':     tripsCsv    = String.fromCharCodes(f.content as List<int>);
      case 'shapes.txt':    shapesCsv   = String.fromCharCodes(f.content as List<int>);
      case 'stops.txt':     stopsCsv    = String.fromCharCodes(f.content as List<int>);
      case 'stop_times.txt':stopTimesCsv= String.fromCharCodes(f.content as List<int>);
    }
  }

  // ── routes.txt ────────────────────────────────────────────────────────────
  // route_id → {shortName, longName, color}
  final routeMeta = <String, (String, String, int)>{}; // (short, long, colorInt)
  if (routesCsv != null) {
    final lines = routesCsv.split('\n');
    if (lines.isNotEmpty) {
      final h = _header(lines[0]);
      final iId    = h['route_id'] ?? -1;
      final iShort = h['route_short_name'] ?? -1;
      final iLong  = h['route_long_name'] ?? -1;
      final iColor = h['route_color'] ?? -1;
      for (int i = 1; i < lines.length; i++) {
        final c = _csvSplit(lines[i]);
        if (c.isEmpty) continue;
        final id    = _cell(c, iId);
        if (id.isEmpty) continue;
        final short = _cell(c, iShort);
        final long  = _cell(c, iLong);
        final colorStr = _cell(c, iColor).replaceAll('#', '');
        final colorInt = colorStr.isNotEmpty
            ? (int.tryParse('FF$colorStr', radix: 16) ?? _pickColor(short, long))
            : _pickColor(short, long);
        routeMeta[id] = (short, long, colorInt);
      }
    }
  }

  // ── trips.txt ─────────────────────────────────────────────────────────────
  // Build: trip_id → route_id, AND route_id → ONE representative shape_id
  final tripRoute   = <String, String>{}; // trip_id → route_id
  final routeShape  = <String, String>{}; // route_id → shape_id (first seen)
  if (tripsCsv != null) {
    final lines = tripsCsv.split('\n');
    if (lines.isNotEmpty) {
      final h = _header(lines[0]);
      final iTrip   = h['trip_id'] ?? -1;
      final iRoute  = h['route_id'] ?? -1;
      final iShape  = h['shape_id'] ?? -1;
      for (int i = 1; i < lines.length; i++) {
        final c = _csvSplit(lines[i]);
        if (c.isEmpty) continue;
        final tripId  = _cell(c, iTrip);
        final routeId = _cell(c, iRoute);
        final shapeId = _cell(c, iShape);
        if (tripId.isEmpty || routeId.isEmpty) continue;
        tripRoute[tripId] = routeId;
        routeShape.putIfAbsent(routeId, () => shapeId); // keep first
      }
    }
  }

  // ── shapes.txt ────────────────────────────────────────────────────────────
  // shape_id → ordered list of LatLng
  final shapePoints = <String, List<(int, double, double)>>{}; // id → [(seq,lat,lng)]
  if (shapesCsv != null) {
    final lines = shapesCsv.split('\n');
    if (lines.isNotEmpty) {
      final h = _header(lines[0]);
      final iId  = h['shape_id'] ?? -1;
      final iLat = h['shape_pt_lat'] ?? -1;
      final iLon = h['shape_pt_lon'] ?? -1;
      final iSeq = h['shape_pt_sequence'] ?? -1;
      for (int i = 1; i < lines.length; i++) {
        final c = _csvSplit(lines[i]);
        if (c.isEmpty) continue;
        final id  = _cell(c, iId);
        if (id.isEmpty) continue;
        final lat = double.tryParse(_cell(c, iLat)) ?? 0;
        final lon = double.tryParse(_cell(c, iLon)) ?? 0;
        final seq = int.tryParse(_cell(c, iSeq)) ?? 0;
        if (lat == 0 && lon == 0) continue;
        shapePoints.putIfAbsent(id, () => []).add((seq, lat, lon));
      }
    }
  }

  // Sort each shape by sequence and convert to LatLng
  final shapes = <String, List<LatLng>>{};
  for (final entry in shapePoints.entries) {
    final pts = entry.value..sort((a, b) => a.$1.compareTo(b.$1));
    shapes[entry.key] = pts.map((p) => LatLng(p.$2, p.$3)).toList();
  }

  // ── stops.txt ─────────────────────────────────────────────────────────────
  final stopMeta = <String, (String, double, double)>{}; // stop_id → (name, lat, lng)
  if (stopsCsv != null) {
    final lines = stopsCsv.split('\n');
    if (lines.isNotEmpty) {
      final h = _header(lines[0]);
      final iId   = h['stop_id'] ?? -1;
      final iName = h['stop_name'] ?? -1;
      final iLat  = h['stop_lat'] ?? -1;
      final iLon  = h['stop_lon'] ?? -1;
      for (int i = 1; i < lines.length; i++) {
        final c = _csvSplit(lines[i]);
        if (c.isEmpty) continue;
        final id  = _cell(c, iId);
        if (id.isEmpty) continue;
        final lat = double.tryParse(_cell(c, iLat)) ?? 0;
        final lon = double.tryParse(_cell(c, iLon)) ?? 0;
        if (lat == 0 && lon == 0) continue;
        stopMeta[id] = (_cell(c, iName), lat, lon);
      }
    }
  }

  // ── stop_times.txt → stop_id to route_id mapping ─────────────────────────
  final stopRoutes = <String, Set<String>>{}; // stop_id → set of route_ids
  if (stopTimesCsv != null) {
    final lines = stopTimesCsv.split('\n');
    if (lines.isNotEmpty) {
      final h = _header(lines[0]);
      final iTrip = h['trip_id'] ?? -1;
      final iStop = h['stop_id'] ?? -1;
      for (int i = 1; i < lines.length; i++) {
        final c = _csvSplit(lines[i]);
        if (c.isEmpty) continue;
        final tripId = _cell(c, iTrip);
        final stopId = _cell(c, iStop);
        if (tripId.isEmpty || stopId.isEmpty) continue;
        final routeId = tripRoute[tripId];
        if (routeId == null) continue;
        stopRoutes.putIfAbsent(stopId, () => {}).add(routeId);
      }
    }
  }

  // ── Build RailLine list ───────────────────────────────────────────────────
  final lines = <RailLine>[];
  for (final entry in routeMeta.entries) {
    final routeId = entry.key;
    final (short, long, colorInt) = entry.value;
    final shapeId = routeShape[routeId] ?? '';
    final path = shapes[shapeId] ?? [];

    lines.add(RailLine(
      id: routeId,
      shortName: short,
      longName: long,
      color: Color(colorInt),
      path: path,
    ));
  }

  // Sort by name for consistent legend ordering
  lines.sort((a, b) => a.displayName.compareTo(b.displayName));

  // ── Build RailStation list ─────────────────────────────────────────────────
  final stations = <RailStation>[];
  for (final entry in stopMeta.entries) {
    final stopId = entry.key;
    final (name, lat, lng) = entry.value;
    final routeIds = (stopRoutes[stopId] ?? {}).toList()..sort();
    stations.add(RailStation(
      id: stopId,
      name: name,
      lat: lat,
      lng: lng,
      lineIds: routeIds,
    ));
  }

  return RailNetwork(lines: lines, stations: stations);
}

// ── Helpers ────────────────────────────────────────────────────────────────────

int _pickColor(String short, String long) {
  final combined = '${short.toLowerCase()} ${long.toLowerCase()}';
  for (final entry in _fallbackColors.entries) {
    if (combined.contains(entry.key)) return entry.value;
  }
  return _defaultColor;
}

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
