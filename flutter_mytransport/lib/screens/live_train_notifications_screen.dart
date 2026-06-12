import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gtfs_realtime_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

class LiveTrainNotificationsScreen extends StatefulWidget {
  const LiveTrainNotificationsScreen({super.key});

  @override
  State<LiveTrainNotificationsScreen> createState() =>
      _LiveTrainNotificationsScreenState();
}

class _LiveTrainNotificationsScreenState
    extends State<LiveTrainNotificationsScreen> {
  GtfsFeed? _feed;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  DateTime? _lastFetched;

  @override
  void initState() {
    super.initState();
    _fetch();
    // Auto-refresh every 30 seconds (matches API update cadence)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetch());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() { _error = null; _loading = _feed == null; });
    try {
      final feed = await GtfsRealtimeService.fetchKtmbVehicles();
      if (!mounted) return;
      setState(() {
        _feed = feed;
        _loading = false;
        _lastFetched = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Group vehicles by route, sorted by route id
  Map<String, List<VehiclePositionData>> get _byRoute {
    final map = <String, List<VehiclePositionData>>{};
    for (final v in (_feed?.vehicles ?? [])) {
      final key = v.routeId.isNotEmpty ? v.routeId : 'Unknown';
      map.putIfAbsent(key, () => []).add(v);
    }
    // Sort: active (in-transit) routes first
    final sorted = map.entries.toList()
      ..sort((a, b) {
        final aMoving = a.value.where((v) => !v.isStopped).length;
        final bMoving = b.value.where((v) => !v.isStopped).length;
        return bMoving.compareTo(aMoving);
      });
    return Map.fromEntries(sorted);
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
            icon: _loading && _feed != null
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
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
    if (_error != null && _feed == null) return _ErrorView(error: _error!, onRetry: _fetch);

    final routes = _byRoute;
    final totalVehicles = _feed?.vehicles.length ?? 0;
    final movingCount = _feed?.vehicles.where((v) => !v.isStopped).length ?? 0;

    return RefreshIndicator(
      onRefresh: _fetch,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ── Live status header ──────────────────────────────────────────
          _LiveStatusHeader(
            totalVehicles: totalVehicles,
            movingCount: movingCount,
            lastFetched: _lastFetched,
            hasError: _error != null,
          ),
          const SizedBox(height: 16),

          // ── Alerts note (service alerts not yet in API) ─────────────────
          const _AlertsComingSoonBanner(),
          const SizedBox(height: 20),

          // ── Section header ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'KTMB Active Trains',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                '${routes.length} route${routes.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Empty state ─────────────────────────────────────────────────
          if (routes.isEmpty)
            const _EmptyState()
          else
            ...routes.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RouteCard(
                  routeId: entry.key,
                  vehicles: entry.value,
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── Live status header ────────────────────────────────────────────────────────

class _LiveStatusHeader extends StatelessWidget {
  final int totalVehicles;
  final int movingCount;
  final DateTime? lastFetched;
  final bool hasError;

  const _LiveStatusHeader({
    required this.totalVehicles,
    required this.movingCount,
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
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.12),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Live dot
          _LiveDot(active: !hasError),
          const SizedBox(width: 12),

          // Counts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalVehicles vehicle${totalVehicles == 1 ? '' : 's'} tracked',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$movingCount in transit · ${totalVehicles - movingCount} stopped',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Last updated
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'KTMB',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _updatedLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
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

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? const Color(0xFF34A853) : AppColors.outline;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: widget.active
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, spreadRadius: 2)]
              : null,
        ),
      ),
    );
  }
}

// ── Alerts coming-soon banner ─────────────────────────────────────────────────

class _AlertsComingSoonBanner extends StatelessWidget {
  const _AlertsComingSoonBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Service alerts & departure times are coming in 2026 via Malaysia\'s GTFS Realtime feed.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.blue.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Route card ────────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final String routeId;
  final List<VehiclePositionData> vehicles;

  const _RouteCard({required this.routeId, required this.vehicles});

  // Pick a consistent color per route
  Color get _routeColor {
    final colors = [
      AppColors.primary,
      const Color(0xFF34A853),
      const Color(0xFFFBBC04),
      const Color(0xFFEA4335),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
    ];
    return colors[routeId.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final moving = vehicles.where((v) => !v.isStopped).length;
    final color = _routeColor;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color bar
            Container(width: 5, color: color),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            routeId,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.train_outlined,
                            size: 13, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          '${vehicles.length} train${vehicles.length == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        _MovingBadge(count: moving, total: vehicles.length),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Vehicle rows (show up to 5)
                    ...vehicles.take(5).map((v) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _VehicleRow(vehicle: v),
                        )),

                    if (vehicles.length > 5)
                      Text(
                        '+${vehicles.length - 5} more trains',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovingBadge extends StatelessWidget {
  final int count;
  final int total;
  const _MovingBadge({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final allStopped = count == 0;
    final color = allStopped ? AppColors.outline : const Color(0xFF34A853);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          allStopped ? 'All stopped' : '$count moving',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _VehicleRow extends StatelessWidget {
  final VehiclePositionData vehicle;
  const _VehicleRow({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final kmh = vehicle.speedKmh;
    final speedText = kmh != null ? '${kmh.round()} km/h' : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Row(
        children: [
          // Train icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: vehicle.isStopped
                  ? AppColors.surfaceVariant
                  : AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              vehicle.isStopped
                  ? Icons.stop_circle_outlined
                  : Icons.directions_railway_outlined,
              size: 15,
              color: vehicle.isStopped
                  ? AppColors.onSurfaceVariant
                  : AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),

          // Label + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.vehicleLabel.isNotEmpty
                      ? vehicle.vehicleLabel
                      : 'Train ${vehicle.entityId}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  vehicle.statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: vehicle.isStopped
                        ? AppColors.onSurfaceVariant
                        : const Color(0xFF34A853),
                  ),
                ),
              ],
            ),
          ),

          // Speed
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                speedText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: vehicle.isStopped
                      ? AppColors.outline
                      : AppColors.primary,
                ),
              ),
              Text(
                vehicle.tripId.isNotEmpty
                    ? 'Trip ${vehicle.tripId.length > 8 ? vehicle.tripId.substring(0, 8) : vehicle.tripId}'
                    : '',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Loading view ──────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Fetching live train data…',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'KTMB via data.gov.my',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signal_wifi_off_outlined,
                size: 48, color: AppColors.outline),
            const SizedBox(height: 16),
            Text(
              'Could not load train data',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.train_outlined, size: 40, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(
            'No active trains at the moment',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Data updates every 30 seconds',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}
