import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gtfs_realtime_service.dart';
import '../services/gtfs_static_schedule_service.dart';
import '../services/transit_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

// ── Route info lookup ─────────────────────────────────────────────────────────
// Maps known routeId patterns → (display name, [dir0 terminus, dir1 terminus])

class _RouteInfo {
  final String name;
  final Color color;
  final List<String> termini; // [direction-0 destination, direction-1 destination]
  const _RouteInfo(this.name, this.color, this.termini);
}

/// Case-insensitive partial-match lookup for a routeId.
_RouteInfo _routeInfo(String routeId) {
  final id = routeId.toUpperCase();

  // ── KTMB ──────────────────────────────────────────────────────────────────
  if (id.contains('PK') || id.contains('PORT') || id.contains('KLANG'))
    return _RouteInfo('Port Klang Line', const Color(0xFF00843D), ['Port Klang', 'Sungai Buloh']);
  if (id.contains('SB') || id.contains('SEREMBAN'))
    return _RouteInfo('Seremban Line', const Color(0xFFCC0000), ['Seremban', 'Batu Caves']);
  if (id.contains('ETS'))
    return _RouteInfo('ETS Intercity', const Color(0xFF1565C0), ['Gemas', 'Padang Besar']);
  if (id.contains('KTM') || id.contains('KOMUTER'))
    return _RouteInfo('KTM Komuter', const Color(0xFF00843D), ['Southbound', 'Northbound']);

  // ── Rapid KL LRT ──────────────────────────────────────────────────────────
  if (id.contains('KJ') || id.contains('KELANA'))
    return _RouteInfo('LRT Kelana Jaya', const Color(0xFFE32026), ['Kelana Jaya', 'Gombak']);
  if (id.contains('AG') || id.contains('AMPANG') || id.contains('SRI-P') || id.contains('SP'))
    return _RouteInfo('LRT Ampang/Sri Petaling', const Color(0xFF8B008B), ['Sentul Timur', 'Sri Petaling / Ampang']);

  // ── Rapid KL MRT ──────────────────────────────────────────────────────────
  if (id.contains('KG') || id.contains('KAJANG'))
    return _RouteInfo('MRT Kajang Line', const Color(0xFF009A44), ['Kajang', 'Sungai Buloh']);
  if (id.contains('PY') || id.contains('PUTRAJAYA'))
    return _RouteInfo('MRT Putrajaya Line', const Color(0xFF78BE20), ['Kwasa Damansara', 'Putrajaya']);

  // ── Rapid KL Monorail ─────────────────────────────────────────────────────
  if (id.contains('MR') || id.contains('MONO'))
    return _RouteInfo('KL Monorail', const Color(0xFFE60000), ['KL Sentral', 'Titiwangsa']);

  // ── BRT ───────────────────────────────────────────────────────────────────
  if (id.contains('BRT') || id.contains('SUNWAY'))
    return _RouteInfo('BRT Sunway', const Color(0xFFFF6600), ['Sunway', 'USJ 7']);

  // Fallback: use raw routeId with generic color
  return _RouteInfo(
    routeId.isNotEmpty ? routeId : 'Unknown Route',
    AppColors.primary,
    ['Terminus A', 'Terminus B'],
  );
}

/// Infer direction from trip_id string (used as fallback when directionId absent).
/// Rapid KL trip IDs often contain "-U-" (up) or "-D-" (down).
int? _inferDirectionFromTripId(String tripId) {
  final t = tripId.toUpperCase();
  if (t.contains('-U-') || t.contains('_UP_') || t.endsWith('_UP')) return 0;
  if (t.contains('-D-') || t.contains('_DN_') || t.endsWith('_DN')) return 1;
  return null;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class LiveTrainNotificationsScreen extends StatefulWidget {
  const LiveTrainNotificationsScreen({super.key});

  @override
  State<LiveTrainNotificationsScreen> createState() =>
      _LiveTrainNotificationsScreenState();
}

class _LiveTrainNotificationsScreenState
    extends State<LiveTrainNotificationsScreen> {
  // ── KTMB live feed ─────────────────────────────────────────────────────────
  AllFeedsResult? _feeds;
  bool _loading = true;
  String? _error;

  // ── Rapid KL scheduled positions ───────────────────────────────────────────
  List<ScheduledVehicle> _scheduledVehicles = [];
  bool _gtfsLoading = true;
  String? _gtfsError;
  int _scheduledActiveRoutes = 0;

  Timer? _refreshTimer;
  DateTime? _lastFetched;

  @override
  void initState() {
    super.initState();
    _fetch();
    _fetchGtfsSchedule();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetch();
      _refreshScheduledVehicles();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── GTFS schedule ──────────────────────────────────────────────────────────

  Future<void> _fetchGtfsSchedule() async {
    if (!mounted) return;
    setState(() { _gtfsLoading = true; _gtfsError = null; });
    try {
      await GtfsStaticScheduleService.getSchedule();
      if (!mounted) return;
      _refreshScheduledVehicles();
    } catch (e) {
      if (!mounted) return;
      setState(() { _gtfsError = e.toString(); _gtfsLoading = false; });
    }
  }

  void _refreshScheduledVehicles() {
    if (!mounted) return;
    final vehicles = GtfsStaticScheduleService.computeCurrentVehicles();
    final routeIds = vehicles.map((v) => v.routeId).toSet();
    setState(() {
      _scheduledVehicles     = vehicles;
      _scheduledActiveRoutes = routeIds.length;
      _gtfsLoading           = false;
    });
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() { _error = null; _loading = _feeds == null; });
    try {
      final feeds = await GtfsRealtimeService.fetchAllOperators();
      if (!mounted) return;
      setState(() {
        _feeds = feeds;
        _loading = false;
        _lastFetched = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // Group vehicles by routeId; empty routeId → 'ktmb-komuter'
  Map<String, List<VehiclePositionData>> _groupByRoute(List<VehiclePositionData> vehicles) {
    final map = <String, List<VehiclePositionData>>{};
    for (final v in vehicles) {
      final key = v.routeId.isNotEmpty ? v.routeId : 'ktmb-komuter';
      map.putIfAbsent(key, () => []).add(v);
    }
    final sorted = map.entries.toList()
      ..sort((a, b) {
        final aMoving = a.value.where((v) => !v.isStopped).length;
        final bMoving = b.value.where((v) => !v.isStopped).length;
        return bMoving.compareTo(aMoving);
      });
    return Map.fromEntries(sorted);
  }

  int get _totalVehicles => _feeds?.ktmb.vehicles.length ?? 0;

  int get _movingCount =>
      _feeds?.ktmb.vehicles.where((v) => !v.isStopped).length ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.08),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Live Train Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _loading && _feeds != null
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _fetch,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.announcement),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _LoadingView();
    if (_error != null && _feeds == null)
      return _ErrorView(error: _error!, onRetry: _fetch);

    final ktmbRoutes = _groupByRoute(_feeds!.ktmb.vehicles);

    return RefreshIndicator(
      onRefresh: _fetch,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ── Live status header ────────────────────────────────────────────
          _LiveStatusHeader(
            totalVehicles: _totalVehicles,
            movingCount: _movingCount,
            scheduledCount: _scheduledVehicles.length,
            lastFetched: _lastFetched,
            hasError: _error != null,
          ),
          const SizedBox(height: 16),

          // ── Info banner ───────────────────────────────────────────────────
          const _InfoBanner(),
          const SizedBox(height: 20),

          // ── KTMB section ─────────────────────────────────────────────────
          _SectionHeader(
            label: 'KTMB Active Trains',
            routeCount: ktmbRoutes.length,
            color: const Color(0xFF00843D),
          ),
          const SizedBox(height: 12),
          if (ktmbRoutes.isEmpty)
            const _EmptyState(message: 'No active KTMB trains')
          else
            ...ktmbRoutes.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RouteCard(routeId: e.key, vehicles: e.value),
                )),

          // ── Rapid KL scheduled section ────────────────────────────────────
          const SizedBox(height: 20),
          _SectionHeader(
            label: 'LRT · MRT · Monorail',
            routeCount: _scheduledActiveRoutes,
            color: const Color(0xFFE32026),
            subtitle: 'Rapid KL — Schedule-based positions',
          ),
          const SizedBox(height: 12),
          if (_gtfsLoading)
            const _ScheduleLoadingCard()
          else if (_gtfsError != null)
            _ScheduleErrorCard(
              error: _gtfsError!,
              onRetry: _fetchGtfsSchedule,
            )
          else if (_scheduledVehicles.isEmpty)
            const _EmptyState(message: 'No active trains right now')
          else
            _ScheduledSection(vehicles: _scheduledVehicles),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int routeCount;
  final Color color;
  final String? subtitle;

  const _SectionHeader({
    required this.label,
    required this.routeCount,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            if (subtitle != null)
              Text(subtitle!, style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.onSurfaceVariant)),
          ]),
        ),
        Text(
          routeCount == 1 ? '1 route' : '$routeCount routes',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── Live status header ────────────────────────────────────────────────────────

class _LiveStatusHeader extends StatelessWidget {
  final int totalVehicles;
  final int movingCount;
  final int scheduledCount;
  final DateTime? lastFetched;
  final bool hasError;

  const _LiveStatusHeader({
    required this.totalVehicles,
    required this.movingCount,
    required this.scheduledCount,
    required this.lastFetched,
    required this.hasError,
  });

  String get _updatedLabel {
    if (lastFetched == null) return 'Updating…';
    final diff = DateTime.now().difference(lastFetched!).inSeconds;
    if (diff < 5) return 'Just now';
    if (diff < 60) return '${diff}s ago';
    return '${diff ~/ 60}m ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.primary.withOpacity(0.12),
          AppColors.primary.withOpacity(0.05),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(children: [
        _LiveDot(active: !hasError),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '$totalVehicles vehicle${totalVehicles == 1 ? '' : 's'} tracked',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.onSurface),
            ),
            const SizedBox(height: 2),
            Text(
              '$movingCount in transit · ${totalVehicles - movingCount} stopped',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
            if (scheduledCount > 0)
              Text(
                '+ $scheduledCount Rapid KL (scheduled est.)',
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFFE32026)),
              ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            'KTMB',
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 0.4, color: AppColors.primary),
          ),
          const SizedBox(height: 2),
          Text(_updatedLabel,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ]),
      ]),
    );
  }
}

class _LiveDot extends StatefulWidget {
  final bool active;
  const _LiveDot({required this.active});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? const Color(0xFF34A853) : AppColors.outline;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: color,
          boxShadow: widget.active
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, spreadRadius: 2)]
              : null,
        ),
      ),
    );
  }
}

// ── Info banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, size: 18, color: Colors.blue.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'KTMB: live GPS via data.gov.my · '
            'LRT/MRT/Monorail: estimated from Prasarana GTFS timetable · '
            'Updates every 30 s',
            style: GoogleFonts.inter(
                fontSize: 12, color: Colors.blue.shade800, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

// ── Route card ────────────────────────────────────────────────────────────────

class _RouteCard extends StatefulWidget {
  final String routeId;
  final List<VehiclePositionData> vehicles;
  const _RouteCard({required this.routeId, required this.vehicles});

  @override
  State<_RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<_RouteCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final info    = _routeInfo(widget.routeId);
    final moving  = widget.vehicles.where((v) => !v.isStopped).length;
    // Show first 5 or all if expanded
    final shown   = _expanded ? widget.vehicles : widget.vehicles.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color bar
            Container(width: 5, color: info.color),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Header row
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: info.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(info.name,
                          style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              letterSpacing: 0.3, color: info.color)),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.train_outlined, size: 13, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text('${widget.vehicles.length} train${widget.vehicles.length == 1 ? '' : 's'}',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.onSurfaceVariant)),
                    const Spacer(),
                    _MovingBadge(count: moving, total: widget.vehicles.length),
                  ]),
                  const SizedBox(height: 10),

                  // Vehicle rows
                  ...shown.map((v) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _VehicleRow(vehicle: v, routeInfo: info),
                      )),

                  // Expand / collapse
                  if (widget.vehicles.length > 5)
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Text(
                        _expanded
                            ? 'Show fewer'
                            : '+${widget.vehicles.length - 5} more trains',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Moving badge ──────────────────────────────────────────────────────────────

class _MovingBadge extends StatelessWidget {
  final int count;
  final int total;
  const _MovingBadge({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final allStopped = count == 0;
    final color = allStopped ? AppColors.outline : const Color(0xFF34A853);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Text(allStopped ? 'All stopped' : '$count moving',
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]);
  }
}

// ── Vehicle row ───────────────────────────────────────────────────────────────

class _VehicleRow extends StatelessWidget {
  final VehiclePositionData vehicle;
  final _RouteInfo routeInfo;
  const _VehicleRow({required this.vehicle, required this.routeInfo});

  /// Resolve destination from directionId, falling back to trip_id inference.
  String _destination() {
    int? dir = vehicle.directionId ?? _inferDirectionFromTripId(vehicle.tripId);
    if (dir != null && routeInfo.termini.length > dir) {
      return routeInfo.termini[dir];
    }
    // No direction info — show both termini as range
    if (routeInfo.termini.length >= 2) {
      return '${routeInfo.termini[0]} ↔ ${routeInfo.termini[1]}';
    }
    return 'Unknown destination';
  }

  /// Nearest station name within 1 km, or null.
  String? _nearestStation() {
    final lat = vehicle.latitude;
    final lng = vehicle.longitude;
    if (lat == null || lng == null) return null;
    return TransitService.findNearestStationName(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final kmh         = vehicle.speedKmh;
    final speedText   = kmh != null ? '${kmh.round()} km/h' : '—';
    final destination = _destination();
    final nearest     = _nearestStation();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Train icon
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: vehicle.isStopped
                ? AppColors.surfaceVariant
                : routeInfo.color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            vehicle.isStopped
                ? Icons.stop_circle_outlined
                : Icons.directions_railway,
            size: 16,
            color: vehicle.isStopped ? AppColors.onSurfaceVariant : routeInfo.color,
          ),
        ),
        const SizedBox(width: 10),

        // Label + destination + nearest station
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Train label
            Text(
              vehicle.vehicleLabel.isNotEmpty
                  ? vehicle.vehicleLabel
                  : 'Train ${vehicle.entityId}',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.onSurface),
            ),
            const SizedBox(height: 2),

            // Destination
            Row(children: [
              Icon(Icons.arrow_forward, size: 11, color: routeInfo.color),
              const SizedBox(width: 3),
              Expanded(
                child: Text(destination,
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: routeInfo.color),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),

            // Nearest station (live location)
            if (nearest != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 11,
                    color: AppColors.onSurfaceVariant),
                const SizedBox(width: 3),
                Expanded(
                  child: Text('Near $nearest',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],

            // Status
            const SizedBox(height: 2),
            Text(vehicle.statusLabel,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: vehicle.isStopped
                        ? AppColors.onSurfaceVariant
                        : const Color(0xFF34A853))),
          ]),
        ),

        // Speed
        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.start, children: [
          Text(speedText,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: vehicle.isStopped ? AppColors.outline : AppColors.primary)),
          if (vehicle.latitude != null && vehicle.longitude != null)
            Text(
              '${vehicle.latitude!.toStringAsFixed(3)}, '
              '${vehicle.longitude!.toStringAsFixed(3)}',
              style: GoogleFonts.inter(fontSize: 9, color: AppColors.outline),
            ),
        ]),
      ]),
    );
  }
}

// ── Schedule loading / error cards ────────────────────────────────────────────

class _ScheduleLoadingCard extends StatelessWidget {
  const _ScheduleLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(children: [
        const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFFE32026)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Downloading Prasarana schedule…',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: AppColors.onSurface)),
            const SizedBox(height: 2),
            Text('LRT/MRT timetable from data.gov.my (~10 s)',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

class _ScheduleErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ScheduleErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Could not load Rapid KL schedule',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: Colors.red.shade800)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(error,
            style: GoogleFonts.inter(
                fontSize: 11, color: Colors.red.shade700),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('Retry'),
          style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
        ),
      ]),
    );
  }
}

// ── Scheduled section (groups by route) ──────────────────────────────────────

class _ScheduledSection extends StatelessWidget {
  final List<ScheduledVehicle> vehicles;
  const _ScheduledSection({required this.vehicles});

  @override
  Widget build(BuildContext context) {
    // Group by routeId, sorted by count desc
    final grouped = <String, List<ScheduledVehicle>>{};
    for (final v in vehicles) {
      grouped.putIfAbsent(v.routeId, () => []).add(v);
    }
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Column(
      children: sorted.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ScheduledRouteCard(routeId: e.key, vehicles: e.value),
      )).toList(),
    );
  }
}

class _ScheduledRouteCard extends StatefulWidget {
  final String routeId;
  final List<ScheduledVehicle> vehicles;
  const _ScheduledRouteCard({required this.routeId, required this.vehicles});

  @override
  State<_ScheduledRouteCard> createState() => _ScheduledRouteCardState();
}

class _ScheduledRouteCardState extends State<_ScheduledRouteCard> {
  bool _expanded = false;

  Color _parseColor(String hex) {
    if (hex.isEmpty) return const Color(0xFFE32026);
    try { return Color(int.parse('FF$hex', radix: 16)); }
    catch (_) { return const Color(0xFFE32026); }
  }

  @override
  Widget build(BuildContext context) {
    final sample  = widget.vehicles.first;
    final color   = _parseColor(sample.routeColor);
    final shown   = _expanded
        ? widget.vehicles
        : widget.vehicles.take(4).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      sample.routeLongName.isNotEmpty
                          ? sample.routeLongName
                          : sample.routeShortName,
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // SCH badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('SCH',
                        style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: Colors.amber.shade800)),
                  ),
                  const Spacer(),
                  Icon(Icons.train_outlined, size: 12,
                      color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text('${widget.vehicles.length}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.onSurfaceVariant)),
                  const SizedBox(width: 4),
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Color(0xFF34A853))),
                  const SizedBox(width: 3),
                  Text('moving',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: const Color(0xFF34A853))),
                ]),
                const SizedBox(height: 10),
                // Vehicle rows
                ...shown.map((v) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ScheduledVehicleRow(vehicle: v, color: color),
                    )),
                if (widget.vehicles.length > 4)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded
                          ? 'Show fewer'
                          : '+${widget.vehicles.length - 4} more trains',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ScheduledVehicleRow extends StatelessWidget {
  final ScheduledVehicle vehicle;
  final Color color;
  const _ScheduledVehicleRow({required this.vehicle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(Icons.directions_railway, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Headsign (destination)
              Row(children: [
                Icon(Icons.arrow_forward, size: 11, color: color),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    vehicle.headsign.isNotEmpty
                        ? vehicle.headsign
                        : (vehicle.directionId == 0 ? 'Outbound' : 'Inbound'),
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const SizedBox(height: 2),
              // Current location
              Text(
                vehicle.locationLabel,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const SizedBox(width: 8),
          // Time to next stop
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(vehicle.minutesToNext,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            Text('next stop',
                style: GoogleFonts.inter(
                    fontSize: 9, color: AppColors.outline)),
          ]),
        ]),
        // Progress bar
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: vehicle.progressFraction,
            minHeight: 3,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ]),
    );
  }
}

// ── Loading / Error / Empty ───────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: AppColors.primary),
        const SizedBox(height: 16),
        Text('Fetching live train data…',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 6),
        Text('KTMB + Rapid KL via data.gov.my',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline)),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.signal_wifi_off_outlined,
              size: 48, color: AppColors.outline),
          const SizedBox(height: 16),
          Text('Could not load train data',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: AppColors.onSurface)),
          const SizedBox(height: 8),
          Text(error,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center, maxLines: 3,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary),
          ),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(children: [
        const Icon(Icons.train_outlined, size: 36, color: AppColors.outline),
        const SizedBox(height: 10),
        Text(message,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text('Data updates every 30 seconds',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline)),
      ]),
    );
  }
}
