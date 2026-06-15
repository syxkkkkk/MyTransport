import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gtfs_static_schedule_service.dart';
import '../services/gtfs_service_alert_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

// ── Category model (passed from landing screen) ───────────────────────────────

class TransitCategory {
  final String label;
  final List<String> routeIds;
  final Color color;
  final IconData icon;
  final String subtitle;

  const TransitCategory({
    required this.label,
    required this.routeIds,
    required this.color,
    required this.icon,
    required this.subtitle,
  });
}

// ── Internal data model ───────────────────────────────────────────────────────

class _StationEntry {
  final GtfsStop stop;
  final double distanceKm; // negative = unknown
  int? etaSecs;

  _StationEntry({required this.stop, required this.distanceKm, this.etaSecs});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class TransitDetailScreen extends StatefulWidget {
  final TransitCategory category;
  const TransitDetailScreen({super.key, required this.category});

  @override
  State<TransitDetailScreen> createState() => _TransitDetailScreenState();
}

class _TransitDetailScreenState extends State<TransitDetailScreen> {
  double? _userLat, _userLng;
  bool _locationLoading = true;
  String? _locationError;

  List<_StationEntry> _stations = [];
  bool _dataReady = false;
  bool _gtfsLoading = false;
  String? _gtfsError;

  // ── Service alerts ──────────────────────────────────────────────────────────
  List<ServiceAlertData> _alerts = [];
  bool _alertsLoading = true;

  Timer? _etaTimer;
  Timer? _alertTimer;

  @override
  void initState() {
    super.initState();
    _initData();
    _fetchAlerts();
    _etaTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshEtas());
    _alertTimer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchAlerts());
  }

  @override
  void dispose() {
    _etaTimer?.cancel();
    _alertTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAlerts() async {
    try {
      final alerts = await GtfsServiceAlertService.fetchAlerts(
        routeIds: widget.category.routeIds,
      );
      if (mounted) setState(() { _alerts = alerts; _alertsLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _alertsLoading = false; });
    }
  }

  Future<void> _initData() async {
    await Future.wait([_fetchLocation(), _ensureGtfsLoaded()]);
    _buildStationList();
  }

  Future<void> _fetchLocation() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) setState(() { _locationError = 'Location services disabled'; _locationLoading = false; });
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() { _locationError = 'Location permission denied'; _locationLoading = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) setState(() { _userLat = pos.latitude; _userLng = pos.longitude; _locationLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _locationError = 'Location unavailable'; _locationLoading = false; });
    }
  }

  Future<void> _ensureGtfsLoaded() async {
    if (GtfsStaticScheduleService.isLoaded) return;
    setState(() { _gtfsLoading = true; });
    try {
      await GtfsStaticScheduleService.getSchedule();
      if (mounted) setState(() { _gtfsLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _gtfsError = e.toString(); _gtfsLoading = false; });
    }
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  void _buildStationList() {
    if (!mounted) return;
    final stops = GtfsStaticScheduleService.stopsForRoutes(widget.category.routeIds);
    final lat = _userLat;
    final lng = _userLng;

    final entries = stops.map((s) {
      final dist = (lat != null && lng != null)
          ? _haversineKm(lat, lng, s.lat, s.lng)
          : -1.0;
      final eta = GtfsStaticScheduleService.nextArrivalSecsAtStop(
          s.stopId, widget.category.routeIds);
      return _StationEntry(stop: s, distanceKm: dist, etaSecs: eta);
    }).toList();

    entries.sort((a, b) {
      if (a.distanceKm < 0 && b.distanceKm < 0) return a.stop.stopName.compareTo(b.stop.stopName);
      if (a.distanceKm < 0) return 1;
      if (b.distanceKm < 0) return -1;
      return a.distanceKm.compareTo(b.distanceKm);
    });

    setState(() { _stations = entries; _dataReady = true; });
  }

  void _refreshEtas() {
    if (!mounted || !_dataReady) return;
    setState(() {
      for (final s in _stations) {
        s.etaSecs = GtfsStaticScheduleService.nextArrivalSecsAtStop(
            s.stop.stopId, widget.category.routeIds);
      }
    });
  }

  String _etaLabel(int? secs) {
    if (secs == null) return '—';
    if (secs < 60) return '<1 min';
    final m = (secs / 60).floor();
    return '$m min';
  }

  String _distLabel(double km) {
    if (km < 0) return '';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.category.color;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.category.label,
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(widget.category.subtitle,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.85))),
        ]),
      ),
      body: _buildBody(),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.announcement),
    );
  }

  Widget _buildBody() {
    if (_gtfsError != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.signal_wifi_off_outlined, size: 48, color: AppColors.outline),
          const SizedBox(height: 16),
          Text('Could not load schedule', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          const SizedBox(height: 8),
          Text(_gtfsError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () { setState(() { _gtfsError = null; }); _initData(); },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: widget.category.color, foregroundColor: Colors.white),
          ),
        ]),
      ));
    }

    if (!_dataReady || _gtfsLoading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: widget.category.color),
        const SizedBox(height: 16),
        Text(_gtfsLoading ? 'Loading schedule\u2026' : 'Getting your location\u2026',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant)),
      ]));
    }

    return RefreshIndicator(
      color: widget.category.color,
      onRefresh: () async {
        await Future.wait([_fetchLocation(), _fetchAlerts()]);
        _buildStationList();
      },
      child: CustomScrollView(slivers: [
        // ── Service alerts ──────────────────────────────────────────────────
        if (_alerts.isNotEmpty)
          SliverToBoxAdapter(child: _AlertsSection(
            alerts: _alerts,
            color: widget.category.color,
          )),

        // ── GPS banner ──────────────────────────────────────────────────────
        if (_locationError != null)
          SliverToBoxAdapter(child: _GpsBanner(
            message: _locationError!,
            onFix: () => Geolocator.openAppSettings(),
          )),

        // ── Stats strip ─────────────────────────────────────────────────────
        SliverToBoxAdapter(child: _StatsStrip(
          stationCount: _stations.length,
          color: widget.category.color,
          hasLocation: _userLat != null,
          nearestName: _stations.isNotEmpty ? _stations.first.stop.stopName : null,
        )),

        // ── Station list ────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final entry = _stations[i];
                final isNearest = i == 0 && _userLat != null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StationTile(
                    entry: entry,
                    color: widget.category.color,
                    isNearest: isNearest,
                    rank: i + 1,
                    etaLabel: _etaLabel(entry.etaSecs),
                    distLabel: _distLabel(entry.distanceKm),
                  ),
                );
              },
              childCount: _stations.length,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Alerts section ────────────────────────────────────────────────────────────

class _AlertsSection extends StatelessWidget {
  final List<ServiceAlertData> alerts;
  final Color color;
  const _AlertsSection({required this.alerts, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
        color: Colors.orange.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(children: [
              Icon(Icons.campaign_outlined, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Text('Service Alerts',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${alerts.length}',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ]),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFFFE0B2)),
          // Alert items
          ...alerts.map((a) => _AlertItem(alert: a)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _AlertItem extends StatefulWidget {
  final ServiceAlertData alert;
  const _AlertItem({required this.alert});

  @override
  State<_AlertItem> createState() => _AlertItemState();
}

class _AlertItemState extends State<_AlertItem> {
  bool _expanded = false;

  Color get _severityColor {
    switch (widget.alert.severity) {
      case 2: return const Color(0xFFD32F2F); // critical
      case 1: return const Color(0xFFF57C00); // warning
      default: return const Color(0xFF1565C0); // info
    }
  }

  IconData get _severityIcon {
    switch (widget.alert.severity) {
      case 2: return Icons.cancel_outlined;
      case 1: return Icons.warning_amber_outlined;
      default: return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    return InkWell(
      onTap: a.descriptionText.isNotEmpty
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(_severityIcon, size: 15, color: _severityColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.displayTitle,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4E2000))),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: _severityColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(a.effectLabel,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _severityColor)),
                  ),
                  if (a.causeLabel != 'Disruption') ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(a.causeLabel,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.orange.shade800)),
                    ),
                  ],
                  if (a.affectedRouteIds.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Text(a.affectedRouteIds.join(', '),
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.orange.shade700)),
                  ],
                ]),
              ]),
            ),
            if (a.descriptionText.isNotEmpty)
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: Colors.orange.shade400),
          ]),
          if (_expanded && a.descriptionText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(a.descriptionText,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF4E2000))),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── GPS banner ────────────────────────────────────────────────────────────────

class _GpsBanner extends StatelessWidget {
  final String message;
  final VoidCallback onFix;
  const _GpsBanner({required this.message, required this.onFix});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(children: [
        Icon(Icons.location_off_outlined, size: 18, color: Colors.amber.shade700),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade800))),
        TextButton(
          onPressed: onFix,
          style: TextButton.styleFrom(
              foregroundColor: Colors.amber.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
          child: const Text('Fix', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}

// ── Stats strip ───────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  final int stationCount;
  final Color color;
  final bool hasLocation;
  final String? nearestName;
  const _StatsStrip({required this.stationCount, required this.color,
      required this.hasLocation, this.nearestName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(Icons.place_outlined, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: hasLocation && nearestName != null
              ? RichText(text: TextSpan(
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurface),
                  children: [
                    const TextSpan(text: 'Nearest: '),
                    TextSpan(text: nearestName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]))
              : Text('$stationCount stations \u2014 sorted alphabetically',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
        ),
        if (hasLocation) ...[
          const SizedBox(width: 8),
          Text('$stationCount stations',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ],
      ]),
    );
  }
}

// ── Station tile ──────────────────────────────────────────────────────────────

class _StationTile extends StatelessWidget {
  final _StationEntry entry;
  final Color color;
  final bool isNearest;
  final int rank;
  final String etaLabel;
  final String distLabel;
  const _StationTile({
    required this.entry, required this.color, required this.isNearest,
    required this.rank, required this.etaLabel, required this.distLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isNearest ? color.withOpacity(0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isNearest ? color.withOpacity(0.3) : AppColors.outlineVariant),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          // Rank circle
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: isNearest ? color : color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$rank',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: isNearest ? Colors.white : color)),
            ),
          ),
          const SizedBox(width: 12),

          // Station name + distance
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(entry.stop.stopName,
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.onSurface),
                      overflow: TextOverflow.ellipsis),
                ),
                if (isNearest)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(8)),
                    child: Text('Nearest',
                        style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
              ]),
              if (distLabel.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.near_me, size: 11, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(distLabel,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.onSurfaceVariant)),
                ]),
              ],
            ]),
          ),
          const SizedBox(width: 12),

          // ETA column
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(etaLabel,
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: entry.etaSecs != null ? color : AppColors.outline)),
            Text('next train',
                style: GoogleFonts.inter(fontSize: 9, color: AppColors.outline)),
          ]),
        ]),
      ),
    );
  }
}
