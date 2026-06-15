import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

// ── Models ────────────────────────────────────────────────────────────────────

class VehiclePositionData {
  final String entityId;
  final String vehicleId;
  final String vehicleLabel;
  final String tripId;
  final String routeId;
  final int? directionId;   // 0 or 1 from GTFS-RT TripDescriptor
  final double? latitude;
  final double? longitude;
  final double? bearing;
  final double? speed; // metres per second
  final int? timestamp; // unix seconds
  final int currentStatus; // 0=INCOMING_AT 1=STOPPED_AT 2=IN_TRANSIT_TO

  const VehiclePositionData({
    required this.entityId,
    required this.vehicleId,
    required this.vehicleLabel,
    required this.tripId,
    required this.routeId,
    this.directionId,
    this.latitude,
    this.longitude,
    this.bearing,
    this.speed,
    this.timestamp,
    this.currentStatus = 2,
  });

  /// Speed converted to km/h, or null if unavailable.
  double? get speedKmh => speed != null ? speed! * 3.6 : null;

  String get statusLabel {
    switch (currentStatus) {
      case 0:
        return 'Incoming';
      case 1:
        return 'Stopped';
      default:
        return 'In Transit';
    }
  }

  bool get isStopped => currentStatus == 1;
}

class GtfsFeed {
  final int? feedTimestamp; // unix seconds from FeedHeader
  final List<VehiclePositionData> vehicles;
  const GtfsFeed({required this.feedTimestamp, required this.vehicles});
}

/// Combined feed result.
/// Note: Rapid KL (LRT/MRT/Monorail) does NOT have a stable GTFS-RT feed
/// yet per data.gov.my docs — only KTMB is available for rail.
class AllFeedsResult {
  final GtfsFeed ktmb;

  const AllFeedsResult({required this.ktmb});
}

// ── Service ───────────────────────────────────────────────────────────────────

class GtfsRealtimeService {
  static const _ktmbUrl = 'https://api.data.gov.my/gtfs-realtime/vehicle-position/ktmb';

  // NOTE: Rapid KL (LRT/MRT/Monorail) GTFS-RT is NOT available yet.
  // Per data.gov.my docs: "rapid-rail-kl does not yet have stable realtime feeds."
  // Only bus feeds exist for Prasarana (rapid-bus-kl, rapid-bus-mrtfeeder, etc.)

  /// Fetch and parse live KTMB vehicle positions.
  static Future<GtfsFeed> fetchKtmbVehicles() async {
    final response = await http
        .get(Uri.parse(_ktmbUrl))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('GTFS API returned HTTP ${response.statusCode}');
    }
    return _parseFeedMessage(response.bodyBytes);
  }

  /// Fetch all available rail feeds (currently only KTMB).
  static Future<AllFeedsResult> fetchAllOperators() async {
    final ktmb = await fetchKtmbVehicles();
    return AllFeedsResult(ktmb: ktmb);
  }

  // ── Top-level FeedMessage parser ──────────────────────────────────────────

  static GtfsFeed _parseFeedMessage(Uint8List bytes) {
    final reader = _ProtoReader(bytes);
    int? feedTimestamp;
    final vehicles = <VehiclePositionData>[];

    while (reader.hasMore) {
      final (:fieldNumber, :wireType) = reader.readTag();
      if (wireType != 2) {
        reader.skip(wireType);
        continue;
      }
      final msgBytes = reader.readBytes();
      switch (fieldNumber) {
        case 1: // FeedHeader
          feedTimestamp = _parseHeader(msgBytes);
        case 2: // FeedEntity (repeated)
          final v = _parseEntity(msgBytes);
          if (v != null) vehicles.add(v);
        default:
          break; // ignore unknown fields
      }
    }

    return GtfsFeed(feedTimestamp: feedTimestamp, vehicles: vehicles);
  }

  // ── FeedHeader → timestamp ────────────────────────────────────────────────

  static int? _parseHeader(Uint8List bytes) {
    final reader = _ProtoReader(bytes);
    while (reader.hasMore) {
      final (:fieldNumber, :wireType) = reader.readTag();
      if (fieldNumber == 3 && wireType == 0) {
        return reader.readVarint(); // uint64 timestamp
      }
      reader.skip(wireType);
    }
    return null;
  }

  // ── FeedEntity ────────────────────────────────────────────────────────────

  static VehiclePositionData? _parseEntity(Uint8List bytes) {
    final reader = _ProtoReader(bytes);
    String entityId = '';
    VehiclePositionData? vehicle;

    while (reader.hasMore) {
      final (:fieldNumber, :wireType) = reader.readTag();
      switch (fieldNumber) {
        case 1 when wireType == 2: // string id
          entityId = reader.readString();
        case 4 when wireType == 2: // VehiclePosition vehicle
          vehicle = _parseVehiclePosition(reader.readBytes(), entityId);
        default:
          reader.skip(wireType);
      }
    }
    return vehicle;
  }

  // ── VehiclePosition ───────────────────────────────────────────────────────

  static VehiclePositionData _parseVehiclePosition(
      Uint8List bytes, String entityId) {
    final reader = _ProtoReader(bytes);
    String tripId = '', routeId = '', vehicleId = '', vehicleLabel = '';
    int? directionId;
    double? lat, lng, bearing, speed;
    int? timestamp;
    int status = 2;

    while (reader.hasMore) {
      final (:fieldNumber, :wireType) = reader.readTag();
      switch (fieldNumber) {
        case 1 when wireType == 2: // TripDescriptor
          final t = _parseTripDescriptor(reader.readBytes());
          tripId = t.$1;
          routeId = t.$2;
          directionId = t.$3;
        case 2 when wireType == 2: // VehicleDescriptor
          final v = _parseVehicleDescriptor(reader.readBytes());
          vehicleId = v.$1;
          vehicleLabel = v.$2;
        case 3 when wireType == 2: // Position
          final p = _parsePosition(reader.readBytes());
          lat = p.$1;
          lng = p.$2;
          bearing = p.$3;
          speed = p.$4;
        case 6 when wireType == 0: // VehicleStopStatus enum
          status = reader.readVarint();
        case 9 when wireType == 0: // uint64 timestamp
          timestamp = reader.readVarint();
        default:
          reader.skip(wireType);
      }
    }

    return VehiclePositionData(
      entityId: entityId,
      vehicleId: vehicleId,
      vehicleLabel: vehicleLabel.isNotEmpty ? vehicleLabel : vehicleId,
      tripId: tripId,
      routeId: routeId,
      directionId: directionId,
      latitude: lat,
      longitude: lng,
      bearing: bearing,
      speed: speed,
      timestamp: timestamp,
      currentStatus: status,
    );
  }

  // ── TripDescriptor → (trip_id, route_id, direction_id) ──────────────────

  static (String, String, int?) _parseTripDescriptor(Uint8List bytes) {
    final reader = _ProtoReader(bytes);
    String tripId = '', routeId = '';
    int? directionId;
    while (reader.hasMore) {
      final (:fieldNumber, :wireType) = reader.readTag();
      if (fieldNumber == 1 && wireType == 2) {
        tripId = reader.readString();
      } else if (fieldNumber == 5 && wireType == 2) {
        routeId = reader.readString();
      } else if (fieldNumber == 6 && wireType == 0) {
        directionId = reader.readVarint(); // 0 or 1
      } else {
        reader.skip(wireType);
      }
    }
    return (tripId, routeId, directionId);
  }

  // ── VehicleDescriptor → (id, label) ──────────────────────────────────────

  static (String, String) _parseVehicleDescriptor(Uint8List bytes) {
    final reader = _ProtoReader(bytes);
    String id = '', label = '';
    while (reader.hasMore) {
      final (:fieldNumber, :wireType) = reader.readTag();
      if (fieldNumber == 1 && wireType == 2) {
        id = reader.readString();
      } else if (fieldNumber == 2 && wireType == 2) {
        label = reader.readString();
      } else {
        reader.skip(wireType);
      }
    }
    return (id, label);
  }

  // ── Position → (lat, lng, bearing, speed) ────────────────────────────────

  static (double?, double?, double?, double?) _parsePosition(Uint8List bytes) {
    final reader = _ProtoReader(bytes);
    double? lat, lng, bearing, speed;
    while (reader.hasMore) {
      final (:fieldNumber, :wireType) = reader.readTag();
      switch (fieldNumber) {
        case 1 when wireType == 5: // float latitude
          lat = reader.readFloat();
        case 2 when wireType == 5: // float longitude
          lng = reader.readFloat();
        case 3 when wireType == 5: // float bearing
          bearing = reader.readFloat();
        case 5 when wireType == 5: // float speed (m/s)
          speed = reader.readFloat();
        default:
          reader.skip(wireType);
      }
    }
    return (lat, lng, bearing, speed);
  }
}

// ── Minimal Protocol Buffer binary reader ─────────────────────────────────────

class _ProtoReader {
  final Uint8List _buf;
  int _pos = 0;

  _ProtoReader(this._buf);

  bool get hasMore => _pos < _buf.length;

  /// Read a base-128 varint (up to 64-bit).
  int readVarint() {
    int result = 0;
    int shift = 0;
    while (_pos < _buf.length) {
      final byte = _buf[_pos++];
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
      if (shift >= 64) break;
    }
    return result;
  }

  /// Read a 32-bit IEEE 754 float (little-endian).
  double readFloat() {
    final bd = ByteData.sublistView(_buf, _pos, _pos + 4);
    _pos += 4;
    return bd.getFloat32(0, Endian.little);
  }

  /// Read a length-delimited field as raw bytes.
  Uint8List readBytes() {
    final len = readVarint();
    final result = Uint8List.sublistView(_buf, _pos, _pos + len);
    _pos += len;
    return result;
  }

  /// Read a length-delimited field as a UTF-8 string.
  String readString() => utf8.decode(readBytes());

  /// Skip a field of the given wire type without reading it.
  void skip(int wireType) {
    switch (wireType) {
      case 0:
        readVarint();
      case 1:
        _pos += 8; // 64-bit
      case 2:
        final len = readVarint();
        _pos += len;
      case 5:
        _pos += 4; // 32-bit
      default:
        throw FormatException('Unknown protobuf wire type: $wireType');
    }
  }

  /// Read the next tag: returns field number and wire type.
  ({int fieldNumber, int wireType}) readTag() {
    final tag = readVarint();
    return (fieldNumber: tag >> 3, wireType: tag & 0x07);
  }
}
