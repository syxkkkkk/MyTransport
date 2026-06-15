import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

// ── Models ────────────────────────────────────────────────────────────────────

class AlertPeriod {
  final int? start; // unix seconds, null = no lower bound
  final int? end;   // unix seconds, null = no upper bound
  const AlertPeriod({this.start, this.end});

  bool isActiveAt(int nowSecs) {
    if (start != null && nowSecs < start!) return false;
    if (end != null && nowSecs > end!) return false;
    return true;
  }
}

class ServiceAlertData {
  final String id;
  final List<AlertPeriod> activePeriods;
  final List<String> affectedRouteIds;
  final List<String> affectedStopIds;
  final int cause;   // GTFS-RT Cause enum value
  final int effect;  // GTFS-RT Effect enum value
  final String headerText;
  final String descriptionText;
  final String url;

  const ServiceAlertData({
    required this.id,
    required this.activePeriods,
    required this.affectedRouteIds,
    required this.affectedStopIds,
    required this.cause,
    required this.effect,
    required this.headerText,
    required this.descriptionText,
    required this.url,
  });

  /// True if this alert has an active time window right now (or no window at all).
  bool isCurrentlyActive() {
    if (activePeriods.isEmpty) return true;
    final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return activePeriods.any((p) => p.isActiveAt(nowSecs));
  }

  /// Human-readable label for the disruption cause.
  String get causeLabel {
    switch (cause) {
      case 2:  return 'Other';
      case 3:  return 'Technical Problem';
      case 4:  return 'Strike';
      case 5:  return 'Demonstration';
      case 6:  return 'Accident';
      case 7:  return 'Holiday';
      case 8:  return 'Weather';
      case 9:  return 'Maintenance';
      case 10: return 'Construction';
      case 11: return 'Police Activity';
      case 12: return 'Medical Emergency';
      default: return 'Disruption';
    }
  }

  /// Human-readable label for the service effect.
  String get effectLabel {
    switch (effect) {
      case 1:  return 'No Service';
      case 2:  return 'Reduced Service';
      case 3:  return 'Significant Delays';
      case 4:  return 'Detour';
      case 5:  return 'Additional Service';
      case 6:  return 'Modified Service';
      case 9:  return 'Stop Moved';
      case 10: return 'No Effect';
      case 11: return 'Accessibility Issue';
      default: return 'Service Affected';
    }
  }

  /// Severity: 0 = info, 1 = warning, 2 = critical.
  int get severity {
    switch (effect) {
      case 1: return 2; // No Service → critical
      case 3: return 1; // Significant Delays → warning
      case 2: return 1; // Reduced Service → warning
      default: return 0;
    }
  }

  /// Best display text: prefer headerText, fall back to effectLabel.
  String get displayTitle =>
      headerText.isNotEmpty ? headerText : effectLabel;

  /// Whether this alert mentions a specific route.
  bool affectsRoute(String routeId) =>
      affectedRouteIds.isEmpty ||
      affectedRouteIds.any((r) => r.toUpperCase() == routeId.toUpperCase());
}

// ── Service ───────────────────────────────────────────────────────────────────

class GtfsServiceAlertService {
  /// Endpoints tried in order; first 200-response with data wins.
  static const _endpoints = [
    'https://api.data.gov.my/gtfs-realtime/service-alert/prasarana',
    'https://api.data.gov.my/gtfs-realtime/service-alert/rapid-rail-kl',
    'https://api.data.gov.my/gtfs-realtime/service-alert/ktmb',
  ];

  /// Fetch currently-active service alerts.
  /// Pass [routeIds] to filter to alerts that affect at least one of those routes
  /// (alerts with no route selector are treated as global and always included).
  static Future<List<ServiceAlertData>> fetchAlerts({
    List<String>? routeIds,
  }) async {
    final allAlerts = <ServiceAlertData>[];

    for (final url in _endpoints) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final parsed = _parseFeed(response.bodyBytes);
          allAlerts.addAll(parsed);
        }
      } catch (_) {
        // Network error or timeout on this endpoint — try next.
      }
    }

    // Deduplicate by id
    final seen = <String>{};
    final deduped = allAlerts.where((a) => seen.add(a.id)).toList();

    // Filter by route if requested
    if (routeIds != null && routeIds.isNotEmpty) {
      return deduped
          .where((a) => routeIds.any((r) => a.affectsRoute(r)))
          .toList();
    }
    return deduped;
  }

  // ── Binary protobuf FeedMessage parser ───────────────────────────────────

  static List<ServiceAlertData> _parseFeed(Uint8List bytes) {
    final reader = _ProtoReader(bytes);
    final alerts = <ServiceAlertData>[];

    while (reader.hasMore) {
      final (:fieldNumber, :wireType) = reader.readTag();
      if (wireType != 2) {
        reader.skip(wireType);
        continue;
      }
      final msgBytes = reader.readBytes();
      if (fieldNumber == 2) {
        // FeedEntity (repeated)
        final alert = _parseEntity(msgBytes);
        if (alert != null && alert.isCurrentlyActive()) alerts.add(alert);
      }
    }
    return alerts;
  }

  static ServiceAlertData? _parseEntity(Uint8List bytes) {
    final reader = _ProtoReader(bytes);
    String id = '';
    ServiceAlertData? alert;

    while (reader.hasMore) {
      final (:fieldNumber, :wireType) = reader.readTag();
      switch (fieldNumber) {
        case 1 when wireType == 2:
          id = reader.readString();
        case 6 when wireType == 2:
          // Alert is field 6 in FeedEntity per GTFS-RT spec
          alert = _parseAlert(reader.readBytes(), id);
        default:
          reader.skip(wireType);
      }
    }
    return alert;
  }

  static ServiceAlertData _parseAlert(Uint8List bytes, String id) {
    final reader = _ProtoReader(bytes);
    final periods = <AlertPeriod>[];
    final routeIds = <String>[];
    final stopIds = <String>[];
    int cause = 1, effect = 8;
    String header = '', description = '', url = '';

    while (reader.hasMore) {
      final (:fieldNumber, :wireType) = reader.readTag();
      switch (fieldNumber) {
        case 1 when wireType == 2:
          // active_period (repeated TimeRange)
          periods.add(_parseTimeRange(reader.readBytes()));
        case 5 when wireType == 2:
          // informed_entity (repeated EntitySelector)
          final (rId, sId) = _parseEntitySelector(reader.readBytes());
          if (rId != null) routeIds.add(rId);
          if (sId != null) stopIds.add(sId);
        case 6 when wireType == 0:
          cause = reader.readVarint();
        case 7 when wireType == 0:
          effect = reader.readVarint();
        case 8 when wireType == 2:
          url = _parseTranslatedString(reader.readBytes());
        case 10 when wireType == 2:
          header = _parseTranslatedString(reader.readBytes());
        case 11 when wireType == 2:
          description = _parseTranslatedString(reader.readBytes());
        default:
          reader.skip(wireType);
      }
    }

    return ServiceAlertData(
      id: id,
      activePeriods: periods,
      affectedRouteIds: routeIds,
      affectedStopIds: stopIds,
      cause: cause,
      effect: effect,
      headerText: header,
      descriptionText: description,
      url: url,
    );
  }

  static AlertPeriod _parseTimeRange(Uint8List bytes) {
    final reader = _ProtoReader(bytes);
    int? start, end;
    while (reader.hasMore) {
      final (:fieldNumber, :wireType) = reader.readTag();
      if (fieldNumber == 1 && wireType == 0) {
        start = reader.readVarint();
      } else if (fieldNumber == 2 && wireType == 0) {
        end = reader.readVarint();
      } else {
        reader.skip(wireType);
      }
    }
    return AlertPeriod(start: start, end: end);
  }

  static (String?, String?) _parseEntitySelector(Uint8List bytes) {
    final reader = _ProtoReader(bytes);
    String? routeId, stopId;
    while (reader.hasMore) {
      final (:fieldNumber, :wireType) = reader.readTag();
      if (fieldNumber == 2 && wireType == 2) {
        routeId = reader.readString();
      } else if (fieldNumber == 5 && wireType == 2) {
        stopId = reader.readString();
      } else {
        reader.skip(wireType);
      }
    }
    return (routeId, stopId);
  }

  /// Parses a TranslatedString, preferring English text.
  static String _parseTranslatedString(Uint8List bytes) {
    final reader = _ProtoReader(bytes);
    String best = '', firstText = '';
    while (reader.hasMore) {
      final (:fieldNumber, :wireType) = reader.readTag();
      if (fieldNumber == 1 && wireType == 2) {
        // Translation sub-message
        final tBytes = reader.readBytes();
        final tReader = _ProtoReader(tBytes);
        String text = '', lang = '';
        while (tReader.hasMore) {
          final t = tReader.readTag();
          if (t.fieldNumber == 1 && t.wireType == 2) {
            text = tReader.readString();
          } else if (t.fieldNumber == 2 && t.wireType == 2) {
            lang = tReader.readString();
          } else {
            tReader.skip(t.wireType);
          }
        }
        if (firstText.isEmpty) firstText = text;
        if (lang == 'en' || lang == 'en-MY') best = text;
      } else {
        reader.skip(wireType);
      }
    }
    return best.isNotEmpty ? best : firstText;
  }
}

// ── Minimal Protocol Buffer binary reader ─────────────────────────────────────

class _ProtoReader {
  final Uint8List _buf;
  int _pos = 0;

  _ProtoReader(this._buf);

  bool get hasMore => _pos < _buf.length;

  int readVarint() {
    int result = 0, shift = 0;
    while (_pos < _buf.length) {
      final byte = _buf[_pos++];
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
      if (shift >= 64) break;
    }
    return result;
  }

  Uint8List readBytes() {
    final len = readVarint();
    final result = Uint8List.sublistView(_buf, _pos, _pos + len);
    _pos += len;
    return result;
  }

  String readString() => utf8.decode(readBytes());

  void skip(int wireType) {
    switch (wireType) {
      case 0:
        readVarint();
      case 1:
        _pos += 8;
      case 2:
        _pos += readVarint();
      case 5:
        _pos += 4;
      default:
        throw FormatException('Unknown protobuf wire type: $wireType');
    }
  }

  ({int fieldNumber, int wireType}) readTag() {
    final tag = readVarint();
    return (fieldNumber: tag >> 3, wireType: tag & 0x07);
  }
}
