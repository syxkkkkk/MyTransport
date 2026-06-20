import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gtfs_bus_stop_service.dart';
import '../services/gtfs_schedule_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import 'bus_route_detail_screen.dart';

// ── Screen ─────────────────────────────────────────────────────────────────────

class NearbyBusScreen extends StatefulWidget {
  const NearbyBusScreen({super.key});

  @override
  State<NearbyBusScreen> createState() => _NearbyBusScreenState();
}

class _NearbyBusScreenState extends State<NearbyBusScreen> {
  Position? _userPos;
  List<GtfsBusStop> _stops = [];
  bool _loadingLocation = true;
  bool _loadingStops = false;
  String? _error;

  // ETA state per stop
  final Map<String, List<GtfsArrival>> _arrivals = {};
  final Map<String, bool> _loadingEta = {};

  double _radiusKm = 1.0;

  @override
  void initState() {
    super.initState();
    _init();
    GtfsScheduleService.preload();
  }

  // ── Location + stops ────────────────────────────────────────────────────────

  Future<void> _init() async {
    setState(() { _loadingLocation = true; _error = null; });

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _error = perm == LocationPermission.deniedForever
            ? 'Location permission permanently denied.\nOpen Settings → App → Permissions and allow Location.'
            : 'Location permission denied. Please allow location access.';
      });
      return;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _error = 'Location (GPS) is turned off.\nPlease enable it in your device settings.';
      });
      return;
    }

    try {
      Position? pos = await Geolocator.getLastKnownPosition();
      if (mounted && pos != null) {
        _userPos = pos;
        setState(() => _loadingLocation = false);
        _loadNearbyStops(pos);
      }

      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      _userPos = fresh;
      setState(() => _loadingLocation = false);
      _loadNearbyStops(fresh);
    } catch (e) {
      if (!mounted) return;
      if (_userPos == null) {
        setState(() {
          _loadingLocation = false;
          _error = 'Could not get your location.\nMake sure GPS is on and try again.';
        });
      }
    }
  }

  Future<void> _loadNearbyStops(Position pos) async {
    setState(() { _loadingStops = true; });
    try {
      final stops = await GtfsBusStopService.getStopsNear(
        pos.latitude,
        pos.longitude,
        radiusM: _radiusKm * 1000,
      );
      if (!mounted) return;
      setState(() {
        _stops = stops;
        _loadingStops = false;
      });
      // Auto-load ETAs for all stops
      for (final stop in stops) {
        _loadEta(stop.stopId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStops = false;
        _error = 'Failed to load bus stops: $e';
      });
    }
  }

  // ── ETA fetch ────────────────────────────────────────────────────────────────

  Future<void> _loadEta(String stopId) async {
    if (_loadingEta[stopId] == true) return;
    setState(() => _loadingEta[stopId] = true);
    try {
      final arrivals = await GtfsScheduleService.getArrivals(
        stopId,
        windowMinutes: 360, // 6-hour window so we always show something
      );
      if (!mounted) return;
      setState(() {
        _arrivals[stopId] = arrivals;
        _loadingEta[stopId] = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _arrivals[stopId] = [];
        _loadingEta[stopId] = false;
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  int _walkMin(GtfsBusStop stop) {
    if (_userPos == null) return 0;
    final d = GtfsBusStopService.distanceTo(
        _userPos!.latitude, _userPos!.longitude, stop.lat, stop.lng);
    return (d / 80).ceil();
  }

  double _distM(GtfsBusStop stop) {
    if (_userPos == null) return 0;
    return GtfsBusStopService.distanceTo(
        _userPos!.latitude, _userPos!.longitude, stop.lat, stop.lng);
  }

  String _distLabel(GtfsBusStop stop) {
    final d = _distM(stop);
    return d < 1000 ? '${d.round()} m' : '${(d / 1000).toStringAsFixed(1)} km';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.08),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Nearby Bus Stops',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        actions: [
          PopupMenuButton<double>(
            icon: const Icon(Icons.tune, color: AppColors.primary),
            tooltip: 'Search radius',
            initialValue: _radiusKm,
            onSelected: (r) {
              setState(() { _radiusKm = r; _arrivals.clear(); });
              if (_userPos != null) _loadNearbyStops(_userPos!);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 0.5, child: Text('500 m')),
              const PopupMenuItem(value: 1.0, child: Text('1 km')),
              const PopupMenuItem(value: 2.0, child: Text('2 km')),
              const PopupMenuItem(value: 5.0, child: Text('5 km')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            tooltip: 'Refresh',
            onPressed: _init,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.home),
    );
  }

  Widget _buildBody() {
    if (_loadingLocation) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Getting your location…',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined,
                  size: 56, color: AppColors.outlineVariant),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _init,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadingStops) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Finding nearby bus stops…',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (_stops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_bus_outlined,
                  size: 56, color: AppColors.outlineVariant),
              const SizedBox(height: 16),
              Text(
                'No bus stops found within ${_radiusKm < 1 ? '${(_radiusKm * 1000).round()} m' : '${_radiusKm.toStringAsFixed(_radiusKm == _radiusKm.roundToDouble() ? 0 : 1)} km'}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try increasing the search radius\nor browse all stops.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() => _radiusKm = (_radiusKm * 2).clamp(0.5, 5.0));
                      if (_userPos != null) _loadNearbyStops(_userPos!);
                    },
                    child: const Text('Wider radius'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => Navigator.pushNamed(context, '/all-bus-stops'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('All Stops Map'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _stops.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final stop = _stops[i];
        return _StopCard(
          stop: stop,
          distLabel: _distLabel(stop),
          walkMin: _walkMin(stop),
          arrivals: _arrivals[stop.stopId],
          loadingEta: _loadingEta[stop.stopId] == true,
          onRefreshEta: () => _loadEta(stop.stopId),
        );
      },
    );
  }
}

// ── Stop card ─────────────────────────────────────────────────────────────────

class _StopCard extends StatelessWidget {
  final GtfsBusStop stop;
  final String distLabel;
  final int walkMin;
  final List<GtfsArrival>? arrivals;
  final bool loadingEta;
  final VoidCallback onRefreshEta;

  const _StopCard({
    required this.stop,
    required this.distLabel,
    required this.walkMin,
    required this.arrivals,
    required this.loadingEta,
    required this.onRefreshEta,
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
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.stopName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.directions_bus_outlined,
                              size: 13, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          const Text(
                            'Bus stop',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.directions_walk,
                              size: 13, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text(
                            '$walkMin min walk',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Circular arrow button
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.outlineVariant),
            const SizedBox(height: 12),

            // ── Arrivals ─────────────────────────────────────────────────────
            if (loadingEta)
              Row(
                children: [
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading schedule…',
                    style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                ],
              )
            else if (arrivals == null || arrivals!.isEmpty)
              Row(
                children: [
                  const Icon(Icons.schedule_outlined,
                      size: 14, color: AppColors.outline),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'No buses scheduled in the next 6 hours.',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: onRefreshEta,
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(40, 28)),
                    child: const Text('Retry', style: TextStyle(fontSize: 12)),
                  ),
                ],
              )
            else
              Column(
                children: [
                  for (int i = 0; i < arrivals!.take(3).length; i++) ...[
                    _ArrivalRow(
                      arrival: arrivals![i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BusRouteDetailScreen(
                            stopId: stop.stopId,
                            stopName: stop.stopName,
                            routeShortName: arrivals![i].routeId,
                          ),
                        ),
                      ),
                    ),
                    if (i < arrivals!.take(3).length - 1)
                      const Divider(
                          height: 16, indent: 0, color: AppColors.outlineVariant),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Arrival row ───────────────────────────────────────────────────────────────

class _ArrivalRow extends StatelessWidget {
  final GtfsArrival arrival;
  final VoidCallback? onTap;
  const _ArrivalRow({required this.arrival, this.onTap});

  String _formatEta(int minutes) {
    if (minutes == 0) return 'Now';
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return '$h hrs ${m.toString().padLeft(2, '0')} min';
    }
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: route badge + direction
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route badge — yellow border style matching reference
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  border: Border.all(
                      color: const Color(0xFFE6A817), width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      arrival.routeId,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.directions_bus,
                        size: 13, color: AppColors.onSurfaceVariant),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              if (arrival.direction.isNotEmpty)
                Text(
                  arrival.direction,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Right: primary ETA + secondary ETA
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (arrival.eta1Min != null)
              Text(
                _formatEta(arrival.eta1Min!),
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              )
            else
              const Text(
                '—',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.outline),
              ),
            if (arrival.eta2Min != null)
              Text(
                '└ ${_formatEta(arrival.eta2Min!)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
          ],
        ),
      ],
    );
  }
}
