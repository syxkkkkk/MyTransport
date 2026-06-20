import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

// ── Bus position model ─────────────────────────────────────────────────────────

class BusPosition {
  final String busNo;
  final String route;
  final double latitude;
  final double longitude;
  final int speed;
  final int angle;
  final String direction;
  final bool engineOn;
  final bool accessible;
  final DateTime receivedAt;

  const BusPosition({
    required this.busNo,
    required this.route,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.angle,
    required this.direction,
    required this.engineOn,
    required this.accessible,
    required this.receivedAt,
  });

  factory BusPosition.fromJson(Map<String, dynamic> j) {
    return BusPosition(
      busNo: j['bus_no']?.toString() ?? '',
      route: j['route']?.toString() ?? '',
      latitude: (j['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (j['longitude'] as num?)?.toDouble() ?? 0.0,
      speed: (j['speed'] as num?)?.toInt() ?? 0,
      angle: (j['angle'] as num?)?.toInt() ?? 0,
      direction: j['dir']?.toString() ?? '01',
      engineOn: j['engine_status']?.toString() == '1',
      accessible: (j['accessibility'] as num?)?.toInt() == 1,
      receivedAt: DateTime.tryParse(j['dt_received']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get speedLabel => speed > 0 ? '$speed km/h' : 'Stopped';
  bool get isRecent => DateTime.now().difference(receivedAt).inMinutes < 5;
}

// ── Bus tracker service (raw Socket.IO over WebSocket) ─────────────────────────

class BusTrackerService {
  // Engine.IO / Socket.IO packet type prefixes
  static const String _sioWsUrl =
      'wss://rapidbus-socketio-avl.prasarana.com.my/socket.io/?EIO=4&transport=websocket';
  static const _provider = 'RKL';
  static const _pingInterval = Duration(seconds: 25);
  static const _refreshInterval = Duration(seconds: 5);

  WebSocket? _ws;
  Timer? _pingTimer;
  Timer? _refreshTimer;
  String _currentRoute = '';
  bool _connected = false;

  final _busesController = StreamController<List<BusPosition>>.broadcast();
  Stream<List<BusPosition>> get busStream => _busesController.stream;

  List<BusPosition> _lastBuses = [];
  List<BusPosition> get lastBuses => _lastBuses;
  bool get isConnected => _connected;

  // ── Public API ──────────────────────────────────────────────────────────────

  void connect({String route = ''}) {
    _currentRoute = route;
    _doConnect();
  }

  void setRoute(String route) {
    _currentRoute = route;
    if (_connected) _sendEvent();
  }

  void disconnect() {
    _pingTimer?.cancel();
    _refreshTimer?.cancel();
    _ws?.close();
    _ws = null;
    _connected = false;
  }

  void dispose() {
    disconnect();
    if (!_busesController.isClosed) _busesController.close();
  }

  // ── Internal connection ─────────────────────────────────────────────────────

  Future<void> _doConnect() async {
    disconnect();
    try {
      debugPrint('[BusTracker] Connecting to AVL server...');
      _ws = await WebSocket.connect(_sioWsUrl);
      debugPrint('[BusTracker] WebSocket connected');

      _ws!.listen(
        _onMessage,
        onError: (e) {
          debugPrint('[BusTracker] WS error: $e');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[BusTracker] WS closed');
          _connected = false;
          _pingTimer?.cancel();
          _refreshTimer?.cancel();
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[BusTracker] Connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    final msg = raw.toString();
    debugPrint('[BusTracker] << $msg');

    if (msg.isEmpty) return;

    final eioType = msg[0];

    switch (eioType) {
      case '0':
        // EIO OPEN — server sent handshake, send SIO CONNECT
        debugPrint('[BusTracker] EIO OPEN received, sending SIO CONNECT');
        _send('40'); // SIO CONNECT to default namespace
        break;

      case '2':
        // EIO PING from server — respond with PONG
        _send('3');
        break;

      case '4':
        // EIO MESSAGE — contains a Socket.IO packet
        if (msg.length < 2) return;
        final sioType = msg[1];

        if (sioType == '0') {
          // SIO CONNECT ACK — now subscribe
          debugPrint('[BusTracker] SIO connected, subscribing...');
          _connected = true;
          _sendEvent();
          // Start polling + ping timers
          _pingTimer?.cancel();
          _pingTimer = Timer.periodic(_pingInterval, (_) => _send('2'));
          _refreshTimer?.cancel();
          _refreshTimer = Timer.periodic(_refreshInterval, (_) => _sendEvent());
        } else if (sioType == '2') {
          // SIO EVENT — parse the JSON array
          _handleSioEvent(msg.substring(2));
        }
        break;
    }
  }

  void _handleSioEvent(String payload) {
    try {
      final arr = jsonDecode(payload) as List<dynamic>;
      final eventName = arr[0] as String;
      if (eventName == 'onFts-client' && arr.length > 1) {
        final buses = _decodeData(arr[1]);
        if (buses != null) {
          _lastBuses = buses;
          debugPrint('[BusTracker] ${buses.length} buses decoded');
          if (!_busesController.isClosed) _busesController.add(buses);
        }
      }
    } catch (e) {
      debugPrint('[BusTracker] Event parse error: $e  payload=$payload');
    }
  }

  void _sendEvent() {
    final payload = jsonEncode([
      'onFts-reload',
      {
        'sid': 'mytransport',
        'uid': '',
        'provider': _provider,
        'route': _currentRoute,
      }
    ]);
    _send('42$payload');
    debugPrint('[BusTracker] >> emit onFts-reload route=$_currentRoute');
  }

  void _send(String data) {
    try {
      _ws?.add(data);
    } catch (e) {
      debugPrint('[BusTracker] Send error: $e');
    }
  }

  Timer? _reconnectTimer;
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _doConnect);
  }

  // ── Decode gzip+base64 bus data ─────────────────────────────────────────────

  List<BusPosition>? _decodeData(dynamic data) {
    try {
      final b64 = data is String ? data : data.toString();
      final bytes = base64.decode(b64);
      final decompressed = GZipDecoder().decodeBytes(bytes);
      final jsonStr = utf8.decode(decompressed);
      final raw = jsonDecode(jsonStr);

      Iterable<Map<String, dynamic>> items;
      if (raw is List) {
        items = raw.whereType<Map<String, dynamic>>();
      } else if (raw is Map<String, dynamic>) {
        items = raw.values.whereType<Map<String, dynamic>>();
      } else {
        debugPrint('[BusTracker] Unexpected data type: ${raw.runtimeType}');
        return null;
      }

      return items
          .map(BusPosition.fromJson)
          .where((b) => b.latitude != 0.0 && b.longitude != 0.0)
          .toList();
    } catch (e, st) {
      debugPrint('[BusTracker] Decode error: $e\n$st');
      return null;
    }
  }
}
