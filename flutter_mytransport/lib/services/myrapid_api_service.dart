import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class ParkingInfo {
  final String stopId;
  final String stationName;
  final int total;
  final int available;
  final double? lat;
  final double? lng;
  final double? pricePerEntry;

  const ParkingInfo({
    required this.stopId,
    required this.stationName,
    required this.total,
    required this.available,
    this.lat,
    this.lng,
    this.pricePerEntry,
  });

  int get occupied => total - available;
  double get occupancyPercent => total > 0 ? occupied / total * 100 : 0;

  /// Availability label: e.g. "467 / 482"
  String get availabilityLabel => '$available / $total';

  /// Colour hint: green = plenty, amber = low, red = full
  ParkingLevel get level {
    if (total == 0) return ParkingLevel.unknown;
    final ratio = available / total;
    if (ratio > 0.3) return ParkingLevel.available;
    if (ratio > 0.05) return ParkingLevel.low;
    return ParkingLevel.full;
  }

  factory ParkingInfo.fromJson(Map<String, dynamic> j) {
    final coords = (j['coordinates'] as Map<String, dynamic>?)?['coordinates'];
    return ParkingInfo(
      stopId: j['stopId'] as String? ?? '',
      stationName: j['name'] as String? ?? '',
      total: j['total'] as int? ?? 0,
      available: j['available'] as int? ?? 0,
      lat: (coords is List && coords.length >= 2) ? (coords[1] as num).toDouble() : null,
      lng: (coords is List && coords.length >= 2) ? (coords[0] as num).toDouble() : null,
      pricePerEntry: (j['pricePerEntry'] as num?)?.toDouble(),
    );
  }
}

enum ParkingLevel { available, low, full, unknown }

// ── Bus Stop ──────────────────────────────────────────────────────────────────

class BusStop {
  final String stopId;
  final String stopName;
  final double lat;
  final double lng;
  final String agencyId;
  final List<String> routeIds;

  const BusStop({
    required this.stopId,
    required this.stopName,
    required this.lat,
    required this.lng,
    required this.agencyId,
    required this.routeIds,
  });

  factory BusStop.fromJson(Map<String, dynamic> j) {
    // Routes can be a list of objects or strings
    final rawRoutes = (j['routes'] ?? j['route_ids'] ?? j['routeIds']) as List<dynamic>? ?? [];
    final routeIds = rawRoutes.map<String>((r) {
      if (r is Map<String, dynamic>) {
        return r['route_id'] as String? ?? r['routeId'] as String? ?? '';
      }
      return r.toString();
    }).where((s) => s.isNotEmpty).toList();

    // Support both GTFS field names (stop_lat/stop_lon) and alternatives (lat/lng/latitude/longitude)
    final latRaw = j['stop_lat'] ?? j['lat'] ?? j['latitude'];
    final lngRaw = j['stop_lon'] ?? j['lng'] ?? j['longitude'] ?? j['stop_long'];

    return BusStop(
      stopId: (j['stop_id'] ?? j['stopId'] ?? j['id'] ?? '').toString(),
      stopName: (j['stop_name'] ?? j['stopName'] ?? j['name'] ?? 'Bus Stop').toString(),
      lat: double.tryParse(latRaw?.toString() ?? '') ?? 0.0,
      lng: double.tryParse(lngRaw?.toString() ?? '') ?? 0.0,
      agencyId: (j['agency_id'] ?? j['agencyId'] ?? 'rapid-kl').toString(),
      routeIds: routeIds,
    );
  }
}

class FacilityStatus {
  final int totalLifts;
  final int brokenLifts;
  final int totalEscalators;
  final int brokenEscalators;
  final String statusMessage;

  const FacilityStatus({
    required this.totalLifts,
    required this.brokenLifts,
    required this.totalEscalators,
    required this.brokenEscalators,
    required this.statusMessage,
  });

  bool get allOperational => brokenLifts == 0 && brokenEscalators == 0;
  int get totalIssues => brokenLifts + brokenEscalators;

  String get liftStatus => brokenLifts == 0
      ? 'All $totalLifts lifts operational'
      : '$brokenLifts of $totalLifts lifts out of service';

  String get escalatorStatus => brokenEscalators == 0
      ? 'All $totalEscalators escalators operational'
      : '$brokenEscalators of $totalEscalators escalators out of service';

  factory FacilityStatus.fromJson(Map<String, dynamic> j) {
    final lift = j['lift'] as Map<String, dynamic>? ?? {};
    final esc = j['escalator'] as Map<String, dynamic>? ?? {};
    return FacilityStatus(
      totalLifts: lift['totalLiftNo'] as int? ?? 0,
      brokenLifts: lift['brokenLiftNo'] as int? ?? 0,
      totalEscalators: esc['totalEscalatorNo'] as int? ?? 0,
      brokenEscalators: esc['brokenEscalatorNo'] as int? ?? 0,
      statusMessage: j['status'] as String? ?? '',
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class MyRapidApiService {
  static const _base = 'https://cr.mapit.myrapid.com.my';
  static const _tokenKey = 'myrapid_token';

  static String? _cachedToken;

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Returns true if a stored token exists.
  static Future<bool> hasToken() async {
    if (_cachedToken != null) return true;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken != null;
  }

  /// Login with email + password. Returns null on failure with an error message.
  static Future<String?> login(String email, String password) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/authen/login/v31'),
            headers: {
              'User-Agent': 'MyRapid/4.0 (Android)',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode == 200) {
        // Extract token from various possible fields
        String? token;
        for (final key in ['token', 'accessToken', 'access_token', 'authToken']) {
          final v = body[key];
          if (v is String && v.isNotEmpty) { token = v; break; }
        }
        final data = body['data'];
        if (token == null && data is Map) {
          for (final key in ['token', 'accessToken', 'access_token']) {
            final v = data[key];
            if (v is String && v.isNotEmpty) { token = v; break; }
          }
        }
        if (token != null) {
          await _saveToken(token);
          return null; // null = success, no error
        }
        return 'Login succeeded but no token in response';
      }

      return body['userMessage'] as String? ??
          body['message'] as String? ??
          'Login failed (HTTP ${resp.statusCode})';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  /// Clear saved token (logout).
  static Future<void> logout() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<void> _saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // ── HTTP helper ───────────────────────────────────────────────────────────

  static Future<({int status, dynamic body})> _get(
      String path, {
      Map<String, String>? params,
    }) async {
    if (_cachedToken == null) {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString(_tokenKey);
    }
    if (_cachedToken == null) {
      return (status: 401, body: null);
    }

    var uri = Uri.parse('$_base$path');
    if (params != null) uri = uri.replace(queryParameters: params);

    final resp = await http
        .get(uri, headers: {
          'User-Agent': 'MyRapid/4.0 (Android)',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_cachedToken',
        })
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode == 401 || resp.statusCode == 403) {
      // Token expired / forbidden — clear it
      await logout();
      return (status: 401, body: null);
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(resp.body);
    } catch (_) {
      return (status: resp.statusCode, body: resp.body);
    }

    // Only treat as auth failure if the body explicitly says so — not just success:false
    // (success:false can mean "no data" which is a valid empty result)
    if (decoded is Map<String, dynamic>) {
      final code = decoded['errorCode']?.toString() ?? decoded['code']?.toString();
      final msg = (decoded['message'] ?? decoded['userMessage'] ?? '').toString().toLowerCase();
      if (code == 'TOKEN_EXPIRED' ||
          code == 'UNAUTHORIZED' ||
          msg.contains('token expired') ||
          msg.contains('invalid token') ||
          msg.contains('please login')) {
        await logout();
        return (status: 401, body: null);
      }
    }

    return (status: resp.statusCode, body: decoded);
  }

  // ── Parking ───────────────────────────────────────────────────────────────

  static List<ParkingInfo>? _cachedParking;
  static DateTime? _parkingFetchedAt;

  /// Returns real-time parking availability for all LRT stations with parking.
  /// Cached for 2 minutes.
  static Future<List<ParkingInfo>> getParkingAvailability() async {
    final now = DateTime.now();
    if (_cachedParking != null &&
        _parkingFetchedAt != null &&
        now.difference(_parkingFetchedAt!).inMinutes < 2) {
      return _cachedParking!;
    }

    final (:status, :body) = await _get('/api/v1/parking/check-availability');
    if (status == 200 && body is List) {
      _cachedParking = body
          .whereType<Map<String, dynamic>>()
          .map(ParkingInfo.fromJson)
          .toList();
      _parkingFetchedAt = now;
      return _cachedParking!;
    }
    return _cachedParking ?? [];
  }

  /// Returns parking info for a specific stop, or null if none.
  static Future<ParkingInfo?> getParkingForStop(String stopId) async {
    final list = await getParkingAvailability();
    try {
      return list.firstWhere(
          (p) => p.stopId.toUpperCase() == stopId.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  // ── Facility status ───────────────────────────────────────────────────────

  static FacilityStatus? _cachedFacility;
  static DateTime? _facilityFetchedAt;

  /// Returns the network-wide lift & escalator status.
  /// Cached for 5 minutes.
  static Future<FacilityStatus?> getNetworkFacilityStatus() async {
    final now = DateTime.now();
    if (_cachedFacility != null &&
        _facilityFetchedAt != null &&
        now.difference(_facilityFetchedAt!).inMinutes < 5) {
      return _cachedFacility;
    }

    final (:status, :body) = await _get('/api/v1/get-facility-status');
    if (status == 200 && body is Map<String, dynamic>) {
      _cachedFacility = FacilityStatus.fromJson(body);
      _facilityFetchedAt = now;
      return _cachedFacility;
    }
    return _cachedFacility;
  }

  // ── Nearby bus stops ──────────────────────────────────────────────────────

  /// Returns bus stops within [radius] metres of [lat]/[lng].
  /// Returns null if authentication failed (token expired/missing).
  static Future<List<BusStop>?> getNearbyBusStops(
    double lat,
    double lng, {
    int radius = 1000,
    String agency = 'rapid-kl',
  }) async {
    debugPrint('[NearbyStops] Querying lat=$lat lng=$lng radius=${radius}m agency=$agency');
    final (:status, :body) = await _get(
      '/nearme/gtfs/stops/v31',
      params: {
        'agency': agency,
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius': radius.toString(),
      },
    );

    if (status == 401) return null; // auth failure — caller should re-login

    if (status != 200 || body is! Map<String, dynamic>) {
      debugPrint('[NearbyStops] HTTP $status body type: ${body.runtimeType}');
      return [];
    }

    debugPrint('[NearbyStops] Top-level keys: ${body.keys.toList()}');

    // The API wraps stops inside body['data']['bus'] but be flexible
    List<dynamic>? busRaw;

    final data = body['data'];
    if (data is Map<String, dynamic>) {
      debugPrint('[NearbyStops] data keys: ${data.keys.toList()}');
      final b = data['bus'];
      if (b is List) busRaw = b;
    } else if (data is List) {
      // data itself is the list of stops
      busRaw = data;
    }

    // Fallback: maybe bus list is at root level
    busRaw ??= body['bus'] as List? ?? body['stops'] as List?;

    if (busRaw == null) {
      debugPrint('[NearbyStops] bus key missing entirely. body=$body');
      return [];
    }
    if (busRaw.isEmpty) {
      debugPrint('[NearbyStops] bus=[] — no Rapid KL stops within ${radius}m of lat=$lat lng=$lng');
      return [];
    }

    debugPrint('[NearbyStops] Raw stop count: ${busRaw.length}');
    if (busRaw.isNotEmpty) {
      debugPrint('[NearbyStops] First stop sample: ${busRaw.first}');
    }

    final stops = <BusStop>[];
    for (final item in busRaw) {
      if (item is Map<String, dynamic>) {
        try {
          final s = BusStop.fromJson(item);
          if (s.lat != 0.0 && s.lng != 0.0) stops.add(s);
        } catch (e) {
          debugPrint('[NearbyStops] Parse error: $e  item=$item');
        }
      }
    }
    debugPrint('[NearbyStops] Parsed ${stops.length} valid stops');
    return stops;
  }
}
