import 'api_service.dart';

class NearbyStation {
  final String id;
  final String code;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final List<StationLine> lines;

  NearbyStation({
    required this.id,
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.lines,
  });

  factory NearbyStation.fromJson(Map<String, dynamic> json) => NearbyStation(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        distanceKm: (json['distanceKm'] as num).toDouble(),
        lines: (json['lines'] as List<dynamic>? ?? [])
            .map((l) => StationLine.fromJson(l as Map<String, dynamic>))
            .toList(),
      );

  /// Returns the primary line color for marker display.
  String get primaryColor {
    if (lines.isEmpty) return '#6B7280';
    return lines.first.line.color;
  }
}

class StationLine {
  final TransitLineInfo line;
  StationLine({required this.line});

  factory StationLine.fromJson(Map<String, dynamic> json) => StationLine(
        line: TransitLineInfo.fromJson(json['line'] as Map<String, dynamic>),
      );
}

class TransitLineInfo {
  final String code;
  final String name;
  final String color;

  TransitLineInfo({required this.code, required this.name, required this.color});

  factory TransitLineInfo.fromJson(Map<String, dynamic> json) => TransitLineInfo(
        code: json['code'] as String,
        name: json['name'] as String,
        color: json['color'] as String,
      );
}

class TransitService {
  final _api = ApiService();

  Future<List<NearbyStation>> getNearbyStations(
    double lat,
    double lon, {
    double radiusKm = 3,
  }) async {
    final res = await _api.get(
      '/transit/stations/nearby?lat=$lat&lon=$lon&radius=$radiusKm',
    );
    final data = res['data'] as List<dynamic>;
    return data
        .map((s) => NearbyStation.fromJson(s as Map<String, dynamic>))
        .toList();
  }
}
