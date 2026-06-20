import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/gtfs_bus_stop_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

class AllBusStopsScreen extends StatefulWidget {
  const AllBusStopsScreen({super.key});

  @override
  State<AllBusStopsScreen> createState() => _AllBusStopsScreenState();
}

class _AllBusStopsScreenState extends State<AllBusStopsScreen> {
  final MapController _mapCtrl = MapController();

  List<GtfsBusStop> _allStops = [];
  List<GtfsBusStop> _visibleStops = [];
  GtfsBusStop? _selected;

  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  double _currentZoom = 11.0;

  // KL/Selangor centre
  static const _defaultCenter = LatLng(3.07, 101.52);

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    setState(() { _loading = true; _error = null; });
    try {
      final stops = await GtfsBusStopService.getAllStops();
      if (!mounted) return;
      setState(() {
        _allStops    = stops;
        _visibleStops = stops;
        _loading     = false;
      });
      // Move to user location if available
      _tryMoveToUser();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error   = 'Failed to load bus stops: $e';
        _loading = false;
      });
    }
  }

  Future<void> _tryMoveToUser() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 14.0);
      }
    } catch (_) {}
  }

  void _onSearch(String q) {
    setState(() {
      _searchQuery = q.toLowerCase().trim();
      _visibleStops = _searchQuery.isEmpty
          ? _allStops
          : _allStops
              .where((s) =>
                  s.stopName.toLowerCase().contains(_searchQuery) ||
                  s.stopId.toLowerCase().contains(_searchQuery))
              .toList();
      _selected = null;
    });
    // If search returns few results, fit map to them
    if (_visibleStops.isNotEmpty && _visibleStops.length <= 20) {
      _fitToStops(_visibleStops);
    }
  }

  void _fitToStops(List<GtfsBusStop> stops) {
    if (stops.isEmpty) return;
    double minLat = stops.first.lat, maxLat = stops.first.lat;
    double minLng = stops.first.lng, maxLng = stops.first.lng;
    for (final s in stops) {
      if (s.lat < minLat) minLat = s.lat;
      if (s.lat > maxLat) maxLat = s.lat;
      if (s.lng < minLng) minLng = s.lng;
      if (s.lng > maxLng) maxLng = s.lng;
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapCtrl.move(center, stops.length == 1 ? 16 : 13);
  }

  // Only render markers when zoomed in enough (performance)
  List<GtfsBusStop> get _renderStops {
    if (_currentZoom >= 14) return _visibleStops;
    if (_currentZoom >= 12) {
      // Sample every 3rd stop to reduce marker count
      return [for (int i = 0; i < _visibleStops.length; i += 3) _visibleStops[i]];
    }
    // Too zoomed out — show nothing (map is just for context)
    return [];
  }

  @override
  Widget build(BuildContext context) {
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
            const Text(
              'All Bus Stops',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (!_loading && _error == null)
              Text(
                '${_visibleStops.length} of ${_allStops.length} stops',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.primary),
            tooltip: 'My location',
            onPressed: _tryMoveToUser,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            tooltip: 'Reload',
            onPressed: () {
              GtfsBusStopService.clearCache();
              _loadStops();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search stop name or ID…',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _onSearch('');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? _LoadingView(message: 'Downloading bus stop data\n(~5 MB, once per day)…')
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadStops)
              : Stack(
                  children: [
                    // ── Map ────────────────────────────────────────────────────
                    FlutterMap(
                      mapController: _mapCtrl,
                      options: MapOptions(
                        initialCenter: _defaultCenter,
                        initialZoom: _currentZoom,
                        onPositionChanged: (pos, _) {
                          final z = pos.zoom;
                          if ((z - _currentZoom).abs() > 0.5) {
                            setState(() => _currentZoom = z);
                          }
                        },
                        onTap: (_, __) => setState(() => _selected = null),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.mytransport.mytransport',
                        ),
                        MarkerLayer(
                          markers: [
                            for (final stop in _renderStops)
                              Marker(
                                point: LatLng(stop.lat, stop.lng),
                                width: _selected?.stopId == stop.stopId ? 36 : 20,
                                height: _selected?.stopId == stop.stopId ? 36 : 20,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _selected = stop);
                                    _mapCtrl.move(
                                        LatLng(stop.lat, stop.lng), 16);
                                  },
                                  child: _StopMarker(
                                    isSelected:
                                        _selected?.stopId == stop.stopId,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // ── Zoom hint (when zoomed out) ────────────────────────────
                    if (_currentZoom < 12 && _searchQuery.isEmpty)
                      Positioned(
                        top: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Text(
                              'Zoom in to see stop pins',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // ── Stop count chip ────────────────────────────────────────
                    if (_currentZoom >= 12 || _searchQuery.isNotEmpty)
                      Positioned(
                        top: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Text(
                              _searchQuery.isEmpty
                                  ? '${_renderStops.length} stops visible'
                                  : '${_visibleStops.length} results',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // ── Selected stop detail ───────────────────────────────────
                    if (_selected != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _StopDetailCard(
                          stop: _selected!,
                          onClose: () => setState(() => _selected = null),
                        ),
                      ),
                  ],
                ),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.home),
    );
  }
}

// ── Stop marker ────────────────────────────────────────────────────────────────

class _StopMarker extends StatelessWidget {
  final bool isSelected;
  const _StopMarker({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.secondary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: isSelected ? 2.5 : 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isSelected ? 0.35 : 0.2),
            blurRadius: isSelected ? 6 : 3,
          ),
        ],
      ),
      child: isSelected
          ? const Icon(Icons.directions_bus, size: 18, color: Colors.white)
          : null,
    );
  }
}

// ── Stop detail card ───────────────────────────────────────────────────────────

class _StopDetailCard extends StatelessWidget {
  final GtfsBusStop stop;
  final VoidCallback onClose;
  const _StopDetailCard({required this.stop, required this.onClose});

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
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondaryFixed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_bus_filled,
                size: 24, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stop.stopName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${stop.stopId}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${stop.lat.toStringAsFixed(5)}, ${stop.lng.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.outline,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.outline,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

// ── Loading view ───────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 48, color: AppColors.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
