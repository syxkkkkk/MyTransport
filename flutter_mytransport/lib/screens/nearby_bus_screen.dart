import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gtfs_bus_stop_service.dart';
import '../services/gtfs_schedule_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

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
  String? _expandedStopId;

  double _radiusKm = 1.0;

  @override
  void initState() {
    super.initState();
    _init();
    // Pre-warm schedule data so the first ETA tap is fast
    GtfsScheduleService.preload();
  }

  // ── Location + stops ────────────────────────────────────────────────────────

  Future<void> _init() async {
    setState(() { _loadingLocation = true; _error = null; });

    // 1 — Check location permission
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

    // 2 — Get position (try last known first, then fresh)
    try {
      Position? pos = await Geolocator.getLastKnownPosition();
      if (mounted && pos != null) {
        _userPos = pos;
        setState(() => _loadingLocation = false);
        _loadNearbyStops(pos);
      }

      // Always also get a fresh fix
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStops = false;
        _error = 'Failed to load bus stops: $e';
      });
    }
  }

  // ── ETA fetch (GTFS schedule-based) ─────────────────────────────────────────

  Future<void> _loadEta(String stopId) async {
    if (_loadingEta[stopId] == true) return;
    setState(() => _loadingEta[stopId] = true);

    try {
      debugPrint('[ETA] Loading schedule-based ETA for stop $stopId');
      final arrivals = await GtfsScheduleService.getArrivals(
        stopId,
        windowMinutes: 90,
      );
      debugPrint('[ETA] Got ${arrivals.length} arrivals for stop $stopId');
      if (!mounted) return;
      setState(() {
        _arrivals[stopId] = arrivals;
        _loadingEta[stopId] = false;
      });
    } catch (e) {
      debugPrint('[ETA] Error: $e');
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Nearby Bus Stops',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          // Radius selector
          PopupMenuButton<double>(
            icon: const Icon(Icons.tune, color: AppColors.primary),
            tooltip: 'Search radius',
            initialValue: _radiusKm,
            onSelected: (r) {
              setState(() => _radiusKm = r);
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
    // Location loading
    if (_loadingLocation) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Getting your location…',
                style: TextStyle(color: Colors.black54)),
          ],
        ),
      );
    }

    // Error
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined,
                  size: 56, color: Colors.black26),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _init,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      );
    }

    // Stops loading
    if (_loadingStops) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finding nearby bus stops…',
                style: TextStyle(color: Colors.black54)),
          ],
        ),
      );
    }

    // No stops found
    if (_stops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_bus_outlined,
                  size: 56, color: Colors.black26),
              const SizedBox(height: 16),
              Text(
                'No bus stops found within ${_radiusKm < 1 ? '${(_radiusKm * 1000).round()} m' : '${_radiusKm.toStringAsFixed(_radiusKm == _radiusKm.roundToDouble() ? 0 : 1)} km'}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try increasing the search radius\nor browse all stops.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54),
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
                    onPressed: () =>
                        Navigator.pushNamed(context, '/all-bus-stops'),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    child: const Text('All Stops Map'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Stop list
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _stops.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final stop = _stops[i];
        final isExpanded = _expandedStopId == stop.stopId;
        return _StopCard(
          stop: stop,
          distLabel: _distLabel(stop),
          walkMin: _walkMin(stop),
          isExpanded: isExpanded,
          arrivals: _arrivals[stop.stopId],
          loadingEta: _loadingEta[stop.stopId] == true,
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedStopId = null;
              } else {
                _expandedStopId = stop.stopId;
                if (!_arrivals.containsKey(stop.stopId)) {
                  _loadEta(stop.stopId);
                }
              }
            });
          },
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
  final bool isExpanded;
  final List<GtfsArrival>? arrivals;
  final bool loadingEta;
  final VoidCallback onTap;
  final VoidCallback onRefreshEta;

  const _StopCard({
    required this.stop,
    required this.distLabel,
    required this.walkMin,
    required this.isExpanded,
    required this.arrivals,
    required this.loadingEta,
    required this.onTap,
    required this.onRefreshEta,
  });



  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header row ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  // Bus stop icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_bus_filled,
                        size: 22, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),

                  // Name + distance
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.stopName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.directions_walk,
                                size: 13, color: Colors.black45),
                            const SizedBox(width: 3),
                            Text(
                              '$walkMin min walk',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                  color: Colors.black26,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              distLabel,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Expand arrow
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        size: 22, color: Colors.black38),
                  ),
                ],
              ),
            ),

            // ── Expanded ETA section ──────────────────────────────────────
            if (isExpanded) ...[
              const Divider(height: 1, indent: 16, endIndent: 16,
                  color: Color(0xFFEEEEEE)),
              if (loadingEta)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Loading schedule…',
                          style: TextStyle(fontSize: 13, color: Colors.black45)),
                    ],
                  ),
                )
              else if (arrivals == null || arrivals!.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_outlined,
                          size: 16, color: Colors.black38),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'No buses scheduled in the next 90 minutes.',
                          style: TextStyle(fontSize: 13, color: Colors.black45),
                        ),
                      ),
                      TextButton(
                        onPressed: onRefreshEta,
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 28)),
                        child: const Text('Retry',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Schedule-based indicator
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            const Icon(Icons.wifi, size: 11, color: Colors.orange),
                            const SizedBox(width: 4),
                            const Text(
                              'Schedule-based · next 90 min',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.black38),
                            ),
                          ],
                        ),
                      ),
                      for (final arr in arrivals!)
                        _ArrivalRow(arrival: arr),
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

// ── Arrival row ───────────────────────────────────────────────────────────────

class _ArrivalRow extends StatelessWidget {
  final GtfsArrival arrival;
  const _ArrivalRow({required this.arrival});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Route badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE6A817), width: 1.5),
            ),
            child: Text(
              arrival.routeId,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF996600),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Direction
          Expanded(
            child: Text(
              arrival.direction.isNotEmpty
                  ? arrival.direction
                  : arrival.routeId,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // ETA column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Signal icon
              Icon(
                Icons.wifi,
                size: 12,
                color: arrival.eta1Min == null
                    ? Colors.black26
                    : arrival.isLive
                        ? const Color(0xFF1B8A3E)
                        : Colors.orange,
              ),
              const SizedBox(height: 2),
              // Primary ETA
              if (arrival.eta1Min != null)
                Text(
                  arrival.eta1Min == 0 ? 'Now' : '${arrival.eta1Min} min',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _etaColor(arrival.eta1Min!),
                    height: 1.1,
                  ),
                )
              else
                const Text('—',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black26)),
              // Secondary ETA
              if (arrival.eta2Min != null)
                Text(
                  '${arrival.eta2Min} min',
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _etaColor(int min) {
    if (min <= 3) return const Color(0xFF1B8A3E);
    if (min <= 8) return const Color(0xFF1565C0);
    return Colors.black87;
  }
}
