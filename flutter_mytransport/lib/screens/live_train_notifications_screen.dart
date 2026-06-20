import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gtfs_realtime_service.dart';
import '../services/gtfs_static_schedule_service.dart';
import '../services/transit_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import 'transit_detail_screen.dart';

// ── Route info lookup ─────────────────────────────────────────────────────────

class _RouteInfo {
  final String name;
  final Color color;
  final List<String> termini;
  const _RouteInfo(this.name, this.color, this.termini);
}

_RouteInfo _routeInfo(String routeId) {
  final id = routeId.toUpperCase();
  if (id.contains('PK') || id.contains('PORT') || id.contains('KLANG'))
    return _RouteInfo('Port Klang Line', const Color(0xFF00843D), ['Port Klang', 'Sungai Buloh']);
  if (id.contains('SB') || id.contains('SEREMBAN'))
    return _RouteInfo('Seremban Line', const Color(0xFFCC0000), ['Seremban', 'Batu Caves']);
  if (id.contains('ETS'))
    return _RouteInfo('ETS Intercity', const Color(0xFF1565C0), ['Gemas', 'Padang Besar']);
  if (id.contains('KTM') || id.contains('KOMUTER'))
    return _RouteInfo('KTM Komuter', const Color(0xFF00843D), ['Port Klang / Seremban', 'Rawang / Batu Caves']);
  if (id.contains('KJ') || id.contains('KELANA'))
    return _RouteInfo('LRT Kelana Jaya', const Color(0xFFE32026), ['Kelana Jaya', 'Gombak']);
  if (id.contains('AG') || id.contains('AMPANG') || id.contains('SRI-P') || id.contains('SP'))
    return _RouteInfo('LRT Ampang/Sri Petaling', const Color(0xFF8B008B), ['Sentul Timur', 'Sri Petaling / Ampang']);
  if (id.contains('KG') || id.contains('KAJANG'))
    return _RouteInfo('MRT Kajang Line', const Color(0xFF009A44), ['Kajang', 'Sungai Buloh']);
  if (id.contains('PY') || id.contains('PUTRAJAYA'))
    return _RouteInfo('MRT Putrajaya Line', const Color(0xFF78BE20), ['Kwasa Damansara', 'Putrajaya']);
  if (id.contains('MR') || id.contains('MONO'))
    return _RouteInfo('KL Monorail', const Color(0xFFE60000), ['KL Sentral', 'Titiwangsa']);
  if (id.contains('BRT') || id.contains('SUNWAY'))
    return _RouteInfo('BRT Sunway', const Color(0xFFFF6600), ['Sunway', 'USJ 7']);
  return _RouteInfo(routeId.isNotEmpty ? routeId : 'Unknown Route', AppColors.primary, ['Outbound', 'Inbound']);
}

int? _inferDirectionFromTripId(String tripId) {
  final t = tripId.toUpperCase();
  if (t.contains('-U-') || t.contains('_UP_') || t.endsWith('_UP')) return 0;
  if (t.contains('-D-') || t.contains('_DN_') || t.endsWith('_DN')) return 1;
  return null;
}

// ── Category definition ───────────────────────────────────────────────────────

class _CatDef {
  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
  final List<String> routeIds; // empty = KTMB (uses live RT)
  final bool isLive;
  const _CatDef({required this.label, required this.subtitle, required this.color,
      required this.icon, required this.routeIds, this.isLive = false});
}

const _kCategories = [
  _CatDef(label: 'KTMB', subtitle: 'Komuter \u00b7 ETS \u00b7 Intercity',
      color: Color(0xFF00843D), icon: Icons.train, routeIds: [], isLive: true),
  _CatDef(label: 'LRT', subtitle: 'Kelana Jaya \u00b7 Ampang \u00b7 Sri Petaling',
      color: Color(0xFFE32026), icon: Icons.subway, routeIds: ['AG', 'KJ', 'PH']),
  _CatDef(label: 'MRT', subtitle: 'Kajang Line \u00b7 Putrajaya Line',
      color: Color(0xFF009A44), icon: Icons.directions_subway, routeIds: ['KGL', 'PYL']),
  _CatDef(label: 'Monorail', subtitle: 'KL Sentral \u2194 Titiwangsa',
      color: Color(0xFFE60000), icon: Icons.tram, routeIds: ['MRL']),
  _CatDef(label: 'BRT', subtitle: 'Sunway Line',
      color: Color(0xFFFF6600), icon: Icons.directions_bus, routeIds: ['BRT']),
];

// ── Main screen ───────────────────────────────────────────────────────────────

class LiveTrainNotificationsScreen extends StatefulWidget {
  const LiveTrainNotificationsScreen({super.key});
  @override
  State<LiveTrainNotificationsScreen> createState() => _LiveTrainNotificationsScreenState();
}

class _LiveTrainNotificationsScreenState extends State<LiveTrainNotificationsScreen> {
  AllFeedsResult? _feeds;
  bool _loading = true;
  String? _error;
  List<ScheduledVehicle> _scheduledVehicles = [];
  bool _gtfsLoading = true;
  Timer? _timer;
  DateTime? _lastFetched;

  @override
  void initState() {
    super.initState();
    _fetch();
    _fetchGtfsSchedule();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetch();
      _refreshScheduled();
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() { _error = null; _loading = _feeds == null; });
    try {
      final feeds = await GtfsRealtimeService.fetchAllOperators();
      if (!mounted) return;
      setState(() { _feeds = feeds; _loading = false; _lastFetched = DateTime.now(); });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _fetchGtfsSchedule() async {
    if (!mounted) return;
    setState(() { _gtfsLoading = true; });
    try {
      await GtfsStaticScheduleService.getSchedule();
      if (!mounted) return;
      _refreshScheduled();
    } catch (_) {
      if (!mounted) return;
      setState(() { _gtfsLoading = false; });
    }
  }

  void _refreshScheduled() {
    if (!mounted) return;
    final v = GtfsStaticScheduleService.computeCurrentVehicles();
    setState(() { _scheduledVehicles = v; _gtfsLoading = false; });
  }

  int _countForCat(_CatDef def) {
    if (def.isLive) return _feeds?.ktmb.vehicles.length ?? 0;
    return _scheduledVehicles.where((v) => def.routeIds.contains(v.routeId)).length;
  }

  void _openCategory(_CatDef def) {
    if (def.isLive) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _KtmbDetailScreen(feeds: _feeds, loading: _loading, error: _error, onRefresh: _fetch),
      ));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => TransitDetailScreen(
          category: TransitCategory(
            label: def.label, routeIds: def.routeIds, color: def.color,
            icon: def.icon, subtitle: def.subtitle,
          ),
        ),
      ));
    }
  }

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
        title: const Text('Transit Lines',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () { _fetch(); _fetchGtfsSchedule(); },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.announcement),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: () async { await _fetch(); },
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // Header
          Text('Select a Transit Network',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          const SizedBox(height: 4),
          Text('Tap a card to view stations nearest to you',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 20),

          // KTMB full-width card
          _CategoryCard(
            def: _kCategories[0],
            activeCount: _countForCat(_kCategories[0]),
            fullWidth: true,
            onTap: () => _openCategory(_kCategories[0]),
          ),
          const SizedBox(height: 12),

          // LRT + MRT row
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _CategoryCard(def: _kCategories[1], activeCount: _countForCat(_kCategories[1]), onTap: () => _openCategory(_kCategories[1]))),
            const SizedBox(width: 12),
            Expanded(child: _CategoryCard(def: _kCategories[2], activeCount: _countForCat(_kCategories[2]), onTap: () => _openCategory(_kCategories[2]))),
          ]),
          const SizedBox(height: 12),

          // Monorail + BRT row
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _CategoryCard(def: _kCategories[3], activeCount: _countForCat(_kCategories[3]), onTap: () => _openCategory(_kCategories[3]))),
            const SizedBox(width: 12),
            Expanded(child: _CategoryCard(def: _kCategories[4], activeCount: _countForCat(_kCategories[4]), onTap: () => _openCategory(_kCategories[4]))),
          ]),
          const SizedBox(height: 28),

          // Info footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'KTMB shows live GPS positions. LRT/MRT/Monorail/BRT use schedule-based estimates from data.gov.my.',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.4),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Category card ─────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final _CatDef def;
  final int activeCount;
  final bool fullWidth;
  final VoidCallback onTap;
  const _CategoryCard({required this.def, required this.activeCount,
      required this.onTap, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: def.color.withOpacity(0.22)),
          boxShadow: [BoxShadow(
              color: def.color.withOpacity(0.07),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row: icon + active badge
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: def.color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(def.icon, color: def.color, size: 22),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: def.color, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 5, height: 5,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.9))),
                const SizedBox(width: 4),
                Text('$activeCount',
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),

          // Name
          Text(def.label,
              style: GoogleFonts.inter(
                  fontSize: fullWidth ? 18 : 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface)),
          const SizedBox(height: 4),

          // Subtitle
          Text(def.subtitle,
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),

          // Bottom row: badge + arrow
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: def.isLive
                    ? const Color(0xFF34A853).withOpacity(0.12)
                    : Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(def.isLive ? '\u25cf LIVE' : '\u25c6 SCHEDULE',
                  style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: def.isLive
                          ? const Color(0xFF34A853)
                          : Colors.amber.shade800)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: def.color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.arrow_forward, size: 13, color: def.color),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── KTMB detail screen (live GPS) ─────────────────────────────────────────────

class _KtmbDetailScreen extends StatefulWidget {
  final AllFeedsResult? feeds;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  const _KtmbDetailScreen({required this.feeds, required this.loading,
      required this.error, required this.onRefresh});
  @override
  State<_KtmbDetailScreen> createState() => _KtmbDetailScreenState();
}

class _KtmbDetailScreenState extends State<_KtmbDetailScreen> {
  AllFeedsResult? _feeds;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _feeds = widget.feeds;
    _loading = widget.loading;
    _error = widget.error;
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      final feeds = await GtfsRealtimeService.fetchAllOperators();
      setState(() { _feeds = feeds; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Map<String, List<VehiclePositionData>> _groupByRoute(List<VehiclePositionData> vehicles) {
    final map = <String, List<VehiclePositionData>>{};
    for (final v in vehicles) {
      final key = v.routeId.isNotEmpty ? v.routeId : 'ktmb-komuter';
      map.putIfAbsent(key, () => []).add(v);
    }
    final sorted = map.entries.toList()
      ..sort((a, b) {
        final aM = a.value.where((v) => !v.isStopped).length;
        final bM = b.value.where((v) => !v.isStopped).length;
        return bM.compareTo(aM);
      });
    return Map.fromEntries(sorted);
  }

  String _destination(VehiclePositionData v, _RouteInfo ri) {
    int? dir = v.directionId ?? _inferDirectionFromTripId(v.tripId);
    if (dir != null && ri.termini.length > dir) return 'To ${ri.termini[dir]}';
    if (ri.termini.length >= 2) return '${ri.termini[0]} \u2194 ${ri.termini[1]}';
    return 'Destination unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00843D),
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('KTMB', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('Live GPS positions', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.85))),
        ]),
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.announcement),
    );
  }

  Widget _buildBody() {
    if (_loading && _feeds == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00843D)));
    }
    if (_error != null && _feeds == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.signal_wifi_off_outlined, size: 48, color: AppColors.outline),
        const SizedBox(height: 16),
        Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00843D), foregroundColor: Colors.white)),
      ])));
    }

    final vehicles = _feeds?.ktmb.vehicles ?? [];
    final grouped = _groupByRoute(vehicles);

    if (grouped.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.train_outlined, size: 48, color: AppColors.outline),
        const SizedBox(height: 12),
        Text('No active KTMB trains', style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant)),
      ]));
    }

    return RefreshIndicator(
      color: const Color(0xFF00843D),
      onRefresh: _refresh,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
        // Summary
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF00843D).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF00843D).withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.train, size: 16, color: Color(0xFF00843D)),
            const SizedBox(width: 8),
            Text('${vehicles.length} trains active \u00b7 ${vehicles.where((v) => !v.isStopped).length} moving',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF00843D))),
            const Spacer(),
            Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF34A853))),
            const SizedBox(width: 4),
            Text('LIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF34A853))),
          ]),
        ),

        for (final entry in grouped.entries) ...[
          _KtmbRouteBlock(routeId: entry.key, vehicles: entry.value, destinationFn: _destination),
          const SizedBox(height: 14),
        ],
      ]),
    );
  }
}

class _KtmbRouteBlock extends StatefulWidget {
  final String routeId;
  final List<VehiclePositionData> vehicles;
  final String Function(VehiclePositionData, _RouteInfo) destinationFn;
  const _KtmbRouteBlock({required this.routeId, required this.vehicles, required this.destinationFn});
  @override
  State<_KtmbRouteBlock> createState() => _KtmbRouteBlockState();
}

class _KtmbRouteBlockState extends State<_KtmbRouteBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ri = _routeInfo(widget.routeId);
    final shown = _expanded ? widget.vehicles : widget.vehicles.take(3).toList();
    final movingCount = widget.vehicles.where((v) => !v.isStopped).length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, color: ri.color),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(ri.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF34A853).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text('\u25cf LIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF34A853))),
                ),
              ]),
              const SizedBox(height: 4),
              Text('${widget.vehicles.length} trains \u00b7 $movingCount moving',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...shown.map((v) {
                final nearest = TransitService.findNearestStationName(v.latitude ?? 0, v.longitude ?? 0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(width: 28, height: 28,
                        decoration: BoxDecoration(color: v.isStopped ? AppColors.surfaceVariant : ri.color.withOpacity(0.12), shape: BoxShape.circle),
                        child: Icon(v.isStopped ? Icons.stop_circle_outlined : Icons.directions_railway, size: 14,
                            color: v.isStopped ? AppColors.onSurfaceVariant : ri.color)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.destinationFn(v, ri),
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ri.color),
                          overflow: TextOverflow.ellipsis),
                      if (nearest != null)
                        Text('Near $nearest \u00b7 ${v.statusLabel}',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis),
                    ])),
                    if (v.speedKmh != null)
                      Text('${v.speedKmh!.round()} km/h',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ]),
                );
              }),
              if (widget.vehicles.length > 3)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Show fewer' : '+${widget.vehicles.length - 3} more trains',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ── Loading / Error ───────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(color: AppColors.primary),
      const SizedBox(height: 16),
      Text('Loading transit data\u2026', style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant)),
    ]));
  }
}
