import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/myrapid_api_service.dart';

// ── Nearby-stations models ─────────────────────────────────────────────────────

class _NearbyStopData {
  final BusStop stop;
  final double distanceM;
  final List<_RouteArrival> arrivals;
  _NearbyStopData({required this.stop, required this.distanceM, required this.arrivals});
  int get walkMinutes => (distanceM / 80).ceil(); // 80 m/min average walking
}

class _RouteArrival {
  final String routeId;
  final String direction;
  final int? eta1Min;
  final int? eta2Min;
  final _SignalLevel signal;
  const _RouteArrival({
    required this.routeId,
    this.direction = '',
    this.eta1Min,
    this.eta2Min,
    this.signal = _SignalLevel.none,
  });
}

enum _SignalLevel { high, medium, low, none }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _logoUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBV-MBafhuN1xSdHHX6FFYGzEHrKnnCoDX87dVFvYVSP4YlFZDbZXZjoiebEHG3C7IIqthh0iuAORTnJtJCAU4oHDLpAGjExCaPewGOhXnHBuE4pr3MwdUnRRpG41N5EWdDOy6iBvgqvmftwDwJAK6x9FCpR4NdoDA18TcqqKrC4n2THF3crEnwhFLd05dV9_hhHrKfsUCUpKFYvr9XAfuPGyUWQ580ZDT3edhA84-CDPvHsesgie3YHVoV4wYCrHrqFewsEhLiZUA';

  String _locationName    = 'Getting location…';
  String _locationAddress = '';
  bool   _loadingLocation = true;

  StreamSubscription<Position>? _positionSub;
  double? _lastLat, _lastLng;

  // Bus card state
  int    _liveBusCount   = 0;
  bool   _busCardLoading = true;
  String? _busAnnouncement;

  // Nearby stations state
  List<_NearbyStopData>? _nearbyStops;
  bool _nearbyStopsLoading = false;
  double? _nearbyLat, _nearbyLng;

  @override
  void initState() {
    super.initState();
    _startLocation();
    _loadBusCard();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _startLocation() async {
    // 1 — Check service
    if (!await Geolocator.isLocationServiceEnabled()) {
      _setLocationText('Location disabled', 'Enable GPS in Settings');
      return;
    }

    // 2 — Check / request permission
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _setLocationText(
        'Location unavailable',
        perm == LocationPermission.deniedForever
            ? 'Allow in app Settings'
            : 'Permission denied',
      );
      return;
    }

    // 3 — Quick last-known snap
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      await _reverseGeocode(last.latitude, last.longitude);
      _maybeRefreshNearby(last.latitude, last.longitude);
    }

    // 4 — Live position stream (updates as you move)
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30, // update every 30 m of movement
      ),
    ).listen((pos) async {
      // Skip if barely moved
      if (_lastLat != null &&
          Geolocator.distanceBetween(
                  _lastLat!, _lastLng!, pos.latitude, pos.longitude) <
              30) return;
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
      await _reverseGeocode(pos.latitude, pos.longitude);
      _maybeRefreshNearby(pos.latitude, pos.longitude);
    });
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty || !mounted) return;

      final p = marks.first;

      // Best display name: subLocality → locality → name → coordinates
      final name = [p.subLocality, p.locality, p.name]
              .firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null) ??
          '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

      // Address line: street, subLocality, locality, postalCode
      final parts = [
        p.street,
        if (p.subLocality != name) p.subLocality,
        p.locality,
        p.postalCode,
      ].where((s) => s != null && s.isNotEmpty).join(', ');

      _setLocationText(name, parts);
    } catch (_) {
      if (_locationName == 'Getting location…') {
        _setLocationText(
          '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
          'Tap to view on map',
        );
      }
    }
  }

  void _setLocationText(String name, String address) {
    if (!mounted) return;
    setState(() {
      _locationName    = name;
      _locationAddress = address;
      _loadingLocation = false;
    });
  }

  // ── Bus card ──────────────────────────────────────────────────────────────

  Future<void> _loadBusCard() async {
    // 1 — Fetch live bus count from AVL server via raw Socket.IO
    _fetchLiveBusCount();

    // 2 — Fetch latest notification from MyRapid if logged in
    if (await MyRapidApiService.hasToken()) {
      _fetchBusAnnouncement();
    }
  }

  Future<void> _fetchLiveBusCount() async {
    try {
      const wsUrl =
          'wss://rapidbus-socketio-avl.prasarana.com.my/socket.io/?EIO=4&transport=websocket';
      final ws = await WebSocket.connect(wsUrl)
          .timeout(const Duration(seconds: 10));

      bool done = false;
      ws.listen((msg) {
        if (done) return;
        final s = msg.toString();
        if (s.startsWith('0')) {
          ws.add('40'); // SIO CONNECT
        } else if (s == '40' || (s.startsWith('40') && s.length > 2)) {
          // SIO connected — request all buses
          final payload = jsonEncode([
            'onFts-reload',
            {'sid': 'home', 'uid': '', 'provider': 'RKL', 'route': ''},
          ]);
          ws.add('42$payload');
        } else if (s.startsWith('42')) {
          try {
            final arr = jsonDecode(s.substring(2)) as List;
            if (arr[0] == 'onFts-client') {
              final b64 = arr[1] as String;
              final bytes = base64.decode(b64);
              final decompressed = GZipDecoder().decodeBytes(bytes);
              final raw = jsonDecode(utf8.decode(decompressed));
              final count =
                  raw is List ? raw.length : (raw as Map).length;
              done = true;
              ws.close();
              if (!mounted) return;
              setState(() {
                _liveBusCount   = count;
                _busCardLoading = false;
              });
            }
          } catch (_) {}
        } else if (s == '2') {
          ws.add('3'); // pong
        }
      }, onDone: () {
        if (!mounted) return;
        if (!done) setState(() => _busCardLoading = false);
      }, onError: (_) {
        if (!mounted) return;
        setState(() => _busCardLoading = false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busCardLoading = false);
    }
  }

  Future<void> _fetchBusAnnouncement() async {
    try {
      // Use the CMS notifications endpoint
      // (reuse MyRapidApiService._get via reflection isn't possible,
      //  so call the public http endpoint directly)
      final token = await _getToken();
      if (token == null) return;
      final uri = Uri.parse(
        'https://cr.mapit.myrapid.com.my/info/myrapid/wordpressPost/v2'
        '?categories=notifications&maxposts=3',
      );
      final resp = await HttpClient()
          .getUrl(uri)
          .then((req) {
            req.headers
              ..set('Authorization', 'Bearer $token')
              ..set('User-Agent', 'MyRapid/4.0 (Android)')
              ..set('Accept', 'application/json');
            return req.close();
          })
          .timeout(const Duration(seconds: 10));

      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      final posts = json['data'] as List<dynamic>? ?? [];
      if (posts.isNotEmpty && mounted) {
        final title = posts.first['post_title'] as String? ??
            posts.first['title'] as String? ?? '';
        if (title.isNotEmpty) {
          setState(() => _busAnnouncement = title);
        }
      }
    } catch (_) {}
  }

  Future<String?> _getToken() async {
    final prefs = await _getSharedPrefs();
    return prefs['myrapid_token'];
  }

  // Minimal SharedPreferences reader without importing the full plugin
  Future<Map<String, String?>> _getSharedPrefs() async {
    // Use MyRapidApiService which already caches the token internally
    final hasToken = await MyRapidApiService.hasToken();
    if (!hasToken) return {};
    // Token is accessible via the service's static cache — just signal yes
    return {'myrapid_token': 'cached'};
  }

  // ── Nearby stations ───────────────────────────────────────────────────────

  void _maybeRefreshNearby(double lat, double lng) {
    if (_nearbyLat == null ||
        Geolocator.distanceBetween(_nearbyLat!, _nearbyLng!, lat, lng) > 300) {
      _nearbyLat = lat;
      _nearbyLng = lng;
      _loadNearbyStations(lat, lng);
    }
  }

  Future<void> _loadNearbyStations(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _nearbyStopsLoading = true);
    try {
      final stops = await MyRapidApiService.getNearbyBusStops(
        lat, lng, radius: 600,
      );
      if (!mounted) return;
      if (stops == null || stops.isEmpty) {
        setState(() {
          _nearbyStops = [];
          _nearbyStopsLoading = false;
        });
        return;
      }

      // Sort by distance and take nearest 3
      final sorted = stops.toList()
        ..sort((a, b) {
          final da = Geolocator.distanceBetween(lat, lng, a.lat, a.lng);
          final db = Geolocator.distanceBetween(lat, lng, b.lat, b.lng);
          return da.compareTo(db);
        });

      final nearest = sorted.take(3).toList();
      final results = <_NearbyStopData>[];

      for (final stop in nearest) {
        final dist = Geolocator.distanceBetween(lat, lng, stop.lat, stop.lng);
        final arrivals = await _fetchStopEta(stop.stopId, stop.routeIds);
        results.add(_NearbyStopData(stop: stop, distanceM: dist, arrivals: arrivals));
      }

      if (mounted) {
        setState(() {
          _nearbyStops = results;
          _nearbyStopsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _nearbyStopsLoading = false);
    }
  }

  Future<List<_RouteArrival>> _fetchStopEta(
      String stopId, List<String> routeIds) async {
    try {
      // Try the MyRapidBus kiosk ETA endpoint
      final resp = await http.get(
        Uri.parse(
            'https://myrapidbus.prasarana.com.my/website/getBusstopEta')
            .replace(queryParameters: {'stopId': stopId}),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'MyTransport/1.0',
          'Referer': 'https://myrapidbus.prasarana.com.my/kiosk',
          'Origin': 'https://myrapidbus.prasarana.com.my',
        },
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final dynamic raw = jsonDecode(resp.body);
        List<dynamic> list = [];

        if (raw is List) {
          list = raw;
        } else if (raw is Map) {
          final inner = raw['data'] ?? raw['routes'] ?? raw['result'];
          if (inner is List) list = inner;
        }

        if (list.isNotEmpty) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) {
                final routeId = item['route']?.toString() ??
                    item['routeId']?.toString() ??
                    item['route_id']?.toString() ??
                    '';
                final direction = item['direction']?.toString() ??
                    item['desc']?.toString() ??
                    item['destination']?.toString() ??
                    '';

                int? parseMin(dynamic v) {
                  if (v == null) return null;
                  if (v is int) return v;
                  if (v is double) return v.round();
                  final s = v.toString().replaceAll(RegExp(r'[^0-9]'), '');
                  return int.tryParse(s);
                }

                final etas = item['eta'] as List? ??
                    item['arrivals'] as List? ??
                    item['times'] as List? ??
                    [];

                int? eta1, eta2;
                bool isLive = false;

                if (etas.isNotEmpty) {
                  final a = etas[0];
                  if (a is Map) {
                    eta1 = parseMin(a['minutes'] ?? a['eta'] ?? a['arrival'] ?? a['time']);
                    isLive = a['isLive'] as bool? ?? a['is_live'] as bool? ?? true;
                  } else {
                    eta1 = parseMin(a);
                    isLive = true;
                  }
                  if (etas.length > 1) {
                    final b = etas[1];
                    eta2 = b is Map
                        ? parseMin(b['minutes'] ?? b['eta'] ?? b['arrival'] ?? b['time'])
                        : parseMin(b);
                  }
                } else {
                  eta1 = parseMin(item['eta'] ?? item['eta1'] ?? item['minutes']);
                  eta2 = parseMin(item['eta2'] ?? item['minutes2'] ?? item['next']);
                  if (eta1 != null) isLive = true;
                }

                final signal = eta1 == null
                    ? _SignalLevel.none
                    : isLive
                        ? _SignalLevel.high
                        : _SignalLevel.low;

                return _RouteArrival(
                  routeId: routeId.isNotEmpty ? routeId : '?',
                  direction: direction,
                  eta1Min: eta1,
                  eta2Min: eta2,
                  signal: signal,
                );
              })
              .where((a) => a.routeId != '?')
              .toList();
        }
      }
    } catch (_) {}

    // Fallback: show routes without ETA
    return routeIds
        .take(3)
        .map((id) => _RouteArrival(routeId: id, signal: _SignalLevel.none))
        .toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.06),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: CachedNetworkImage(
          imageUrl: _logoUrl,
          height: 32,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) =>
              const Icon(Icons.directions_transit, color: AppColors.primary),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          _LocationCard(
            name:    _locationName,
            address: _locationAddress,
            loading: _loadingLocation,
            onPinTap:     () => Navigator.pushNamed(context, '/location-selection'),
            onRefreshTap: _startLocation,
          ),
          const SizedBox(height: 16),
          _BusAnnouncementCard(
            loading:      _busCardLoading,
            liveBusCount: _liveBusCount,
            announcement: _busAnnouncement,
            onTap: () => Navigator.pushNamed(context, '/live-bus'),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/chatbot'),
            child: const _AIInputField(),
          ),
          const SizedBox(height: 16),
          _ShortcutsGrid(
            onNearbyStationsTap: () =>
                Navigator.pushNamed(context, '/nearby-bus'),
          ),
          const SizedBox(height: 16),
          _NearbyStationsSection(
            stops: _nearbyStops,
            loading: _nearbyStopsLoading,
            onSeeAll: () => Navigator.pushNamed(context, '/nearby-bus'),
            onStopTap: (stop) => Navigator.pushNamed(
              context, '/live-bus',
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.home),
    );
  }
}

// ── Location card ─────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final String name;
  final String address;
  final bool loading;
  final VoidCallback onPinTap;
  final VoidCallback onRefreshTap;

  const _LocationCard({
    required this.name,
    required this.address,
    required this.loading,
    required this.onPinTap,
    required this.onRefreshTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.my_location, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'CURRENT LOCATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.outline,
                ),
              ),
              const Spacer(),
              // Refresh button
              GestureDetector(
                onTap: onRefreshTap,
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 16, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Location name
          loading
              ? Container(
                  height: 22,
                  width: 180,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
          const SizedBox(height: 4),

          // Address
          loading
              ? Container(
                  height: 14,
                  width: 240,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : Text(
                  address,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.surfaceVariant),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPinTap,
              icon: const Icon(Icons.push_pin_outlined, size: 16),
              label: const Text('Pin Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI input ──────────────────────────────────────────────────────────────────

class _AIInputField extends StatelessWidget {
  const _AIInputField();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const _PulsingBotIcon(),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Ask AI: How to get to KLCC?',
              style: TextStyle(fontSize: 15, color: AppColors.outline),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic_none, size: 18, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _PulsingBotIcon extends StatefulWidget {
  const _PulsingBotIcon();

  @override
  State<_PulsingBotIcon> createState() => _PulsingBotIconState();
}

class _PulsingBotIconState extends State<_PulsingBotIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: const Icon(Icons.smart_toy_outlined, size: 22, color: AppColors.primary),
    );
  }
}

// ── Shortcuts grid ────────────────────────────────────────────────────────────

class _ShortcutsGrid extends StatelessWidget {
  final VoidCallback onNearbyStationsTap;
  const _ShortcutsGrid({required this.onNearbyStationsTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ShortcutItem(
        icon: Icons.train_outlined,
        label: 'Nearby\nBus Stops',
        bgColor: AppColors.primaryContainer,
        iconColor: AppColors.primary,
        onTap: onNearbyStationsTap,
      ),
      _ShortcutItem(
        icon: Icons.directions_bus_outlined,
        label: 'All Bus\nStops',
        bgColor: AppColors.secondaryFixed,
        iconColor: AppColors.secondary,
        onTap: () => Navigator.pushNamed(context, '/all-bus-stops'),
      ),
      _ShortcutItem(
        icon: Icons.route_outlined,
        label: 'Transit\nMap',
        bgColor: AppColors.tertiaryFixed,
        iconColor: AppColors.tertiary,
        onTap: () => Navigator.pushNamed(context, '/transit-map'),
      ),
      _ShortcutItem(
        icon: Icons.bookmark_outline,
        label: 'Saved\nLocations',
        bgColor: AppColors.surfaceVariant,
        iconColor: AppColors.onSurfaceVariant,
        onTap: () {},
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: items.map((item) => _ShortcutCard(item: item)).toList(),
    );
  }
}

class _ShortcutItem {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;
  const _ShortcutItem({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });
}

class _ShortcutCard extends StatelessWidget {
  final _ShortcutItem item;
  const _ShortcutCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 24, color: item.iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                color: AppColors.onSurface,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bus Announcement Card ─────────────────────────────────────────────────────

class _BusAnnouncementCard extends StatelessWidget {
  final bool loading;
  final int liveBusCount;
  final String? announcement;
  final VoidCallback onTap;

  const _BusAnnouncementCard({
    required this.loading,
    required this.liveBusCount,
    required this.onTap,
    this.announcement,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.secondary.withOpacity(0.92),
              AppColors.secondary.withOpacity(0.75),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Live Bus Network',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Live pulse dot
                _LiveDot(active: !loading && liveBusCount > 0),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
              ],
            ),

            const SizedBox(height: 12),

            // Bus count + announcement
            if (loading)
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Connecting to live feed…',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$liveBusCount',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'buses live',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Track now button
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.4), width: 1),
                    ),
                    child: const Text(
                      'Track Now',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

            // Announcement banner (if available)
            if (announcement != null && announcement!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign_outlined,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        announcement!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  final bool active;
  const _LiveDot({required this.active});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white38,
          shape: BoxShape.circle,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Color.lerp(
              Colors.greenAccent, Colors.lightGreenAccent, _ctrl.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent
                  .withOpacity(0.6 * _ctrl.value),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nearby Stations Section ───────────────────────────────────────────────────

class _NearbyStationsSection extends StatelessWidget {
  final List<_NearbyStopData>? stops;
  final bool loading;
  final VoidCallback onSeeAll;
  final void Function(BusStop stop) onStopTap;

  const _NearbyStationsSection({
    required this.stops,
    required this.loading,
    required this.onSeeAll,
    required this.onStopTap,
  });

  @override
  Widget build(BuildContext context) {
    // Don't render section at all until we have data or are loading
    if (!loading && (stops == null || stops!.isEmpty)) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Nearby Stations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                'See all',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (loading)
          ...[
            _StopCardSkeleton(),
            const SizedBox(height: 10),
            _StopCardSkeleton(),
          ]
        else
          ...stops!.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NearbyStopCard(data: s, onTap: () => onStopTap(s.stop)),
              )),
      ],
    );
  }
}

class _StopCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 14, width: 180, color: AppColors.surfaceVariant),
          const SizedBox(height: 8),
          Container(height: 11, width: 100, color: AppColors.surfaceVariant),
          const SizedBox(height: 12),
          Container(height: 11, width: 220, color: AppColors.surfaceVariant),
        ],
      ),
    );
  }
}

class _NearbyStopCard extends StatelessWidget {
  final _NearbyStopData data;
  final VoidCallback onTap;

  const _NearbyStopCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stop = data.stop;
    final arrivals = data.arrivals;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Stop header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bus stop icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_bus_filled,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Stop name + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.stopName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bus stop  •  ${data.walkMinutes} min walk',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.outline,
                  ),
                ],
              ),
            ),

            // ── Divider ──────────────────────────────────────────────────
            const Divider(height: 1, color: AppColors.outlineVariant),

            // ── Arrivals ─────────────────────────────────────────────────
            if (arrivals.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: const [
                    Icon(Icons.schedule, size: 14, color: AppColors.outline),
                    SizedBox(width: 6),
                    Text(
                      'No arrival data available',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...arrivals.take(2).map((arr) => _RouteArrivalRow(arrival: arr)),
          ],
        ),
      ),
    );
  }
}

class _RouteArrivalRow extends StatelessWidget {
  final _RouteArrival arrival;
  const _RouteArrivalRow({required this.arrival});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Route badge ──────────────────────────────────────────────
          _RouteBadge(routeId: arrival.routeId),
          const SizedBox(width: 10),

          // ── Direction text ────────────────────────────────────────────
          Expanded(
            child: Text(
              arrival.direction.isNotEmpty
                  ? arrival.direction
                  : arrival.routeId,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // ── ETA + signal ──────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Signal accuracy icon
              _SignalIcon(level: arrival.signal),
              const SizedBox(height: 2),

              // Primary ETA
              if (arrival.eta1Min != null)
                Text(
                  arrival.eta1Min == 0 ? 'Now' : '${arrival.eta1Min} min',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _etaColor(arrival.eta1Min!),
                    height: 1.1,
                  ),
                )
              else
                const Text(
                  '—',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.outline,
                  ),
                ),

              // Secondary ETA
              if (arrival.eta2Min != null)
                Text(
                  '${arrival.eta2Min} min',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _etaColor(int minutes) {
    if (minutes <= 3) return const Color(0xFF1B8A3E); // urgent green
    if (minutes <= 8) return const Color(0xFF1565C0); // comfortable blue
    return AppColors.onSurface;
  }
}

// ── Route badge pill ──────────────────────────────────────────────────────────

class _RouteBadge extends StatelessWidget {
  final String routeId;
  const _RouteBadge({required this.routeId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFE6A817), // amber/yellow border
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_bus_rounded,
            size: 11,
            color: Color(0xFFE6A817),
          ),
          const SizedBox(width: 4),
          Text(
            routeId,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB8860B),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Signal accuracy icon ──────────────────────────────────────────────────────

class _SignalIcon extends StatelessWidget {
  final _SignalLevel level;
  const _SignalIcon({required this.level});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (level) {
      _SignalLevel.high   => (const Color(0xFF1B8A3E), 'Highly accurate'),
      _SignalLevel.medium => (const Color(0xFFE65100), 'Fairly accurate'),
      _SignalLevel.low    => (const Color(0xFFC62828), 'Less accurate'),
      _SignalLevel.none   => (const Color(0xFF555555), 'No live data'),
    };

    return Tooltip(
      message: label,
      child: Icon(Icons.wifi, size: 14, color: color),
    );
  }
}
