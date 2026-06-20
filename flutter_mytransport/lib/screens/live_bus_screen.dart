import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/bus_tracker_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

class LiveBusScreen extends StatefulWidget {
  const LiveBusScreen({super.key});

  @override
  State<LiveBusScreen> createState() => _LiveBusScreenState();
}

class _LiveBusScreenState extends State<LiveBusScreen> {
  final MapController _mapController = MapController();
  final BusTrackerService _tracker = BusTrackerService();
  final TextEditingController _routeCtrl = TextEditingController();

  List<BusPosition> _buses = [];
  BusPosition? _selectedBus;
  bool _connecting = true;
  bool _hasError = false;
  int _busCount = 0;
  StreamSubscription<List<BusPosition>>? _sub;
  Position? _userPos;

  @override
  void initState() {
    super.initState();
    _sub = _tracker.busStream.listen(
      (buses) {
        if (!mounted) return;
        setState(() {
          _buses = buses;
          _busCount = buses.length;
          _connecting = false;
          _hasError = false;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() { _connecting = false; _hasError = true; });
      },
    );
    _tracker.connect(route: '');
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      setState(() => _userPos = pos);
      _mapController.move(LatLng(pos.latitude, pos.longitude), 13.0);
    } catch (_) {}
  }

  void _applyRouteFilter(String route) {
    final r = route.trim().toUpperCase();
    _routeCtrl.text = r;
    setState(() { _connecting = true; _selectedBus = null; });
    _tracker.setRoute(r);
  }

  void _clearFilter() {
    _routeCtrl.clear();
    setState(() { _connecting = true; _selectedBus = null; });
    _tracker.setRoute('');
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tracker.dispose();
    _routeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userLatLng = _userPos != null
        ? LatLng(_userPos!.latitude, _userPos!.longitude)
        : const LatLng(3.1390, 101.6869);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Bus Tracker',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (!_connecting)
              Text(
                '$_busCount buses tracked',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
          ],
        ),
        actions: [
          // Live indicator
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _connecting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : _hasError
                    ? const Icon(Icons.wifi_off, size: 18, color: Colors.red)
                    : const _PulsingDot(),
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.primary),
            onPressed: _getLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Route filter bar ─────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _routeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Filter by route (e.g. T154, U6000)',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: AppColors.outline),
                      prefixIcon: const Icon(Icons.route, size: 18,
                          color: AppColors.primary),
                      suffixIcon: _routeCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: _clearFilter,
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.outlineVariant),
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: _applyRouteFilter,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _applyRouteFilter(_routeCtrl.text),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Go', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),

          // ── Map ──────────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: userLatLng,
                    initialZoom: 12.0,
                    onTap: (_, __) => setState(() => _selectedBus = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.mytransport.mytransport',
                    ),
                    MarkerLayer(
                      markers: [
                        // User location
                        if (_userPos != null)
                          Marker(
                            point: userLatLng,
                            width: 18,
                            height: 18,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.primary.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Bus markers
                        ..._buses.map((bus) => Marker(
                              point: LatLng(bus.latitude, bus.longitude),
                              width: 30,
                              height: 30,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedBus = bus),
                                child: _BusMarker(
                                  bus: bus,
                                  isSelected:
                                      _selectedBus?.busNo == bus.busNo,
                                ),
                              ),
                            )),
                      ],
                    ),
                  ],
                ),

                // Connecting overlay
                if (_connecting && _buses.isEmpty)
                  Container(
                    color: Colors.black.withValues(alpha: 0.15),
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Connecting to live bus feed…'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // No buses found
                if (!_connecting && _buses.isEmpty && !_hasError)
                  Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_bus_outlined,
                                size: 40, color: AppColors.outline),
                            const SizedBox(height: 8),
                            Text(
                              _routeCtrl.text.isEmpty
                                  ? 'No buses online right now'
                                  : 'No buses found for route "${_routeCtrl.text}"',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Error
                if (_hasError)
                  Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off,
                                size: 40, color: Colors.red),
                            const SizedBox(height: 8),
                            const Text('Connection failed'),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () {
                                setState(() {
                                  _connecting = true;
                                  _hasError = false;
                                });
                                _tracker.connect(route: _routeCtrl.text);
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Selected bus card
                if (_selectedBus != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _BusDetailCard(
                      bus: _selectedBus!,
                      onClose: () => setState(() => _selectedBus = null),
                      onFocus: () => _mapController.move(
                        LatLng(_selectedBus!.latitude,
                            _selectedBus!.longitude),
                        15.0,
                      ),
                    ),
                  ),

                // Popular routes chip row (when no filter)
                if (_routeCtrl.text.isEmpty &&
                    !_connecting &&
                    _selectedBus == null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _QuickRoutes(onSelect: _applyRouteFilter),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.home),
    );
  }
}

// ── Bus marker widget ──────────────────────────────────────────────────────────

class _BusMarker extends StatelessWidget {
  final BusPosition bus;
  final bool isSelected;
  const _BusMarker({required this.bus, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? AppColors.primary
        : bus.engineOn
            ? AppColors.secondary
            : AppColors.outline;

    return Transform.rotate(
      angle: bus.angle * math.pi / 180,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 3,
            ),
          ],
        ),
        child: Icon(
          Icons.navigation,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Bus detail card ────────────────────────────────────────────────────────────

class _BusDetailCard extends StatelessWidget {
  final BusPosition bus;
  final VoidCallback onClose;
  final VoidCallback onFocus;
  const _BusDetailCard(
      {required this.bus, required this.onClose, required this.onFocus});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  bus.route,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                bus.busNo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.center_focus_strong, size: 20),
                color: AppColors.primary,
                tooltip: 'Focus on map',
                onPressed: onFocus,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.outline,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _StatChip(
                icon: Icons.speed,
                label: bus.speedLabel,
                color: bus.speed > 0 ? AppColors.secondary : AppColors.outline,
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.explore,
                label: '${bus.angle}°',
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              if (bus.accessible)
                _StatChip(
                  icon: Icons.accessible,
                  label: 'Accessible',
                  color: Colors.green,
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bus.engineOn
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: bus.engineOn ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      bus.engineOn ? 'Running' : 'Stopped',
                      style: TextStyle(
                        fontSize: 11,
                        color: bus.engineOn ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Direction ${bus.direction} • Updated ${_age(bus.receivedAt)}',
            style: const TextStyle(
                fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _age(DateTime t) {
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 60) return '${s}s ago';
    return '${s ~/ 60}m ago';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Quick route chips ──────────────────────────────────────────────────────────

class _QuickRoutes extends StatelessWidget {
  final ValueChanged<String> onSelect;
  static const _popular = [
    'T154', 'U6000', 'U3000', 'T780', 'P0010', 'U2500',
  ];
  const _QuickRoutes({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'POPULAR ROUTES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _popular
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(r,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                          backgroundColor: AppColors.primaryContainer,
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onPressed: () => onSelect(r),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing live dot ───────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Color.lerp(Colors.green, Colors.lightGreen, _ctrl.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
