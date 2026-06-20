import 'dart:async';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A lightweight service that downloads the Rapid KL bus GTFS static feed
/// from data.gov.my and extracts only stops.txt — giving lat/lng for every
/// bus stop in the network (KL + Selangor + surroundings).
class GtfsBusStopService {
  // Public category URLs on data.gov.my
  static const _busKlUrl =
      'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl';

  // In-memory cache (cleared each day)
  static List<GtfsBusStop>? _cached;
  static Uint8List? _rawBytes;         // shared with GtfsScheduleService
  static String? _cacheDate;
  static Completer<List<GtfsBusStop>>? _inFlight;

  static bool get isLoaded => _cached != null;
  static int  get count    => _cached?.length ?? 0;

  static String today() {
    final now = DateTime.now();
    final d = now.hour < 3 ? now.subtract(const Duration(days: 1)) : now;
    return '${d.year}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';
  }

  /// Returns all bus stops from the Rapid KL bus GTFS feed.
  /// Downloads once per day; subsequent calls return the cached list.
  static Future<List<GtfsBusStop>> getAllStops() async {
    final today = GtfsBusStopService.today();
    if (_cached != null && _cacheDate == today) return _cached!;
    if (_inFlight != null) return _inFlight!.future;

    final completer = Completer<List<GtfsBusStop>>();
    _inFlight = completer;

    try {
      debugPrint('[GtfsBusStop] Downloading rapid-bus-kl GTFS...');
      final resp = await http
          .get(Uri.parse(_busKlUrl))
          .timeout(const Duration(seconds: 90));

      if (resp.statusCode != 200) {
        throw Exception('GTFS bus HTTP ${resp.statusCode}');
      }

      debugPrint('[GtfsBusStop] Downloaded ${(resp.bodyBytes.length / 1024).toStringAsFixed(0)} KB, parsing...');

      final bytes = resp.bodyBytes;
      _rawBytes  = bytes;           // cache raw bytes for schedule service
      final stops = await compute(_parseStopsInIsolate, bytes);

      debugPrint('[GtfsBusStop] Parsed ${stops.length} bus stops');
      _cached    = stops;
      _cacheDate = today;
      _inFlight  = null;
      completer.complete(stops);
      return stops;
    } catch (e, st) {
      _inFlight = null;
      debugPrint('[GtfsBusStop] Error: $e\n$st');
      completer.completeError(e);
      rethrow;
    }
  }

  /// Returns stops within [radiusM] metres of [lat]/[lng].
  static Future<List<GtfsBusStop>> getStopsNear(
    double lat,
    double lng, {
    double radiusM = 1000,
  }) async {
    final all = await getAllStops();
    return all
        .where((s) => _distM(lat, lng, s.lat, s.lng) <= radiusM)
        .toList()
      ..sort((a, b) =>
          _distM(lat, lng, a.lat, a.lng).compareTo(_distM(lat, lng, b.lat, b.lng)));
  }

  static double _distM(double lat1, double lng1, double lat2, double lng2) =>
      distanceTo(lat1, lng1, lat2, lng2);

  /// Flat-earth distance in metres — accurate to ~0.1% within 100 km.
  static double distanceTo(double lat1, double lng1, double lat2, double lng2) {
    final dLat = (lat2 - lat1) * 111320.0;
    final dLng = (lng2 - lng1) * 111320.0 * cos(lat1 * pi / 180);
    return sqrt(dLat * dLat + dLng * dLng);
  }

  /// Returns the raw ZIP bytes, downloading if needed.
  /// Used by [GtfsScheduleService] so both services share a single download.
  static Future<Uint8List> getRawBytes() async {
    final today = GtfsBusStopService.today();
    if (_rawBytes != null && _cacheDate == today) return _rawBytes!;
    await getAllStops(); // will download and populate _rawBytes
    return _rawBytes!;
  }

  static void clearCache() {
    _cached    = null;
    _rawBytes  = null;
    _cacheDate = null;
  }
}

// ── Isolate parser ─────────────────────────────────────────────────────────────

List<GtfsBusStop> _parseStopsInIsolate(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);

  String? stopsCsv;
  for (final f in archive) {
    if (f.name.endsWith('stops.txt') && f.isFile) {
      stopsCsv = String.fromCharCodes(f.content as List<int>);
      break;
    }
  }
  if (stopsCsv == null) return [];

  final stops = <GtfsBusStop>[];
  final lines = stopsCsv.split('\n');
  if (lines.isEmpty) return [];

  // Parse header
  final header = lines[0].split(',').map((h) => h.trim().toLowerCase()).toList();
  int col(String name) => header.indexOf(name);
  final idxId   = col('stop_id');
  final idxName = col('stop_name');
  final idxLat  = col('stop_lat');
  final idxLon  = col('stop_lon');

  if (idxId < 0 || idxLat < 0 || idxLon < 0) return [];

  for (int i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    // Simple CSV split (handles quoted commas)
    final cells = _csvSplit(line);
    if (cells.length <= idxLat || cells.length <= idxLon) continue;

    final id  = idxId < cells.length ? cells[idxId].trim() : '';
    if (id.isEmpty) continue;

    final lat = double.tryParse(cells[idxLat].trim()) ?? 0.0;
    final lng = double.tryParse(cells[idxLon].trim()) ?? 0.0;
    if (lat == 0.0 && lng == 0.0) continue;

    final name = idxName >= 0 && idxName < cells.length
        ? cells[idxName].replaceAll('"', '').trim()
        : id;

    stops.add(GtfsBusStop(stopId: id, stopName: name, lat: lat, lng: lng));
  }

  return stops;
}

List<String> _csvSplit(String line) {
  final result = <String>[];
  final buf = StringBuffer();
  bool inQuote = false;
  for (int i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      inQuote = !inQuote;
    } else if (c == ',' && !inQuote) {
      result.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  result.add(buf.toString());
  return result;
}

// ── Model ──────────────────────────────────────────────────────────────────────

class GtfsBusStop {
  final String stopId;
  final String stopName;
  final double lat;
  final double lng;

  const GtfsBusStop({
    required this.stopId,
    required this.stopName,
    required this.lat,
    required this.lng,
  });
}
