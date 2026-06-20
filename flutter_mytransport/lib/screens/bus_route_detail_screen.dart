import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gtfs_schedule_service.dart';
import '../theme/app_theme.dart';

class BusRouteDetailScreen extends StatefulWidget {
  final String stopId;
  final String stopName;
  final String routeShortName;

  const BusRouteDetailScreen({
    super.key,
    required this.stopId,
    required this.stopName,
    required this.routeShortName,
  });

  @override
  State<BusRouteDetailScreen> createState() => _BusRouteDetailScreenState();
}

class _BusRouteDetailScreenState extends State<BusRouteDetailScreen> {
  RouteDetail? _detail;
  bool _loading = true;
  String? _error;
  int _directionId = 0;
  bool _showAllTimes = false;

  final _currentStopKey = GlobalKey();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail({int? direction}) async {
    final dir = direction ?? _directionId;
    setState(() { _loading = true; _error = null; _showAllTimes = false; });

    try {
      final detail = await GtfsScheduleService.getRouteDetail(
        widget.stopId,
        widget.routeShortName,
        directionId: dir,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _directionId = detail?.directionId ?? dir;
        _loading = false;
      });

      // Auto-scroll to the current stop after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_currentStopKey.currentContext != null) {
          Scrollable.ensureVisible(
            _currentStopKey.currentContext!,
            alignment: 0.35,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

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
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // Route badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                border: Border.all(color: const Color(0xFFE6A817), width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.routeShortName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.directions_bus,
                      size: 14, color: AppColors.onSurfaceVariant),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _detail?.headsign ?? widget.stopName,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Loading route…',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (_error != null || _detail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.route_outlined,
                  size: 56, color: AppColors.outlineVariant),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Route data not available.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadDetail,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      );
    }

    final detail = _detail!;

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // ── Route header card ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.headsign,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              if (detail.hasOtherDirection) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    final newDir = 1 - detail.directionId;
                    _directionId = newDir;
                    _loadDetail(direction: newDir);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Change direction',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Stop timeline ──────────────────────────────────────────────────
        ...List.generate(detail.stops.length, (i) {
          final stop = detail.stops[i];
          final isCurrent = i == detail.currentStopIndex;
          final isFirst = i == 0;
          final isLast = i == detail.stops.length - 1;

          return _StopTimelineItem(
            key: isCurrent ? _currentStopKey : null,
            stopName: stop.stopName,
            isCurrent: isCurrent,
            isFirst: isFirst,
            isLast: isLast,
            extraContent: isCurrent
                ? _CurrentStopExtra(
                    nextDeparture: detail.nextDepartureStr,
                    scheduledTimes: detail.allScheduledTimes,
                    showAll: _showAllTimes,
                    onToggle: () =>
                        setState(() => _showAllTimes = !_showAllTimes),
                  )
                : null,
          );
        }),
      ],
    );
  }
}

// ── Timeline item ──────────────────────────────────────────────────────────────

class _StopTimelineItem extends StatelessWidget {
  final String stopName;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;
  final Widget? extraContent;

  static const _lineColor = Color(0xFFE6A817);
  static const _lineWidth = 2.0;
  static const _colWidth = 28.0;
  static const _dotSize = 12.0;

  const _StopTimelineItem({
    super.key,
    required this.stopName,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline column ─────────────────────────────────────────────
          SizedBox(
            width: _colWidth,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Top line
                Expanded(
                  child: Center(
                    child: Container(
                      width: _lineWidth,
                      color: isFirst ? Colors.transparent : _lineColor,
                    ),
                  ),
                ),
                // Dot or location pin for current stop
                if (isCurrent)
                  const Icon(Icons.location_on,
                      color: AppColors.primary, size: 22)
                else
                  Container(
                    width: _dotSize,
                    height: _dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _lineColor,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                // Bottom line
                Expanded(
                  child: Center(
                    child: Container(
                      width: _lineWidth,
                      color: isLast ? Colors.transparent : _lineColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Stop name + extra content ────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stopName,
                    style: GoogleFonts.inter(
                      fontSize: isCurrent ? 16 : 14,
                      fontWeight: isCurrent
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isCurrent
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (extraContent != null) ...[
                    const SizedBox(height: 12),
                    extraContent!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Current stop extra content ─────────────────────────────────────────────────

class _CurrentStopExtra extends StatelessWidget {
  final String? nextDeparture;
  final List<String> scheduledTimes;
  final bool showAll;
  final VoidCallback onToggle;

  const _CurrentStopExtra({
    required this.nextDeparture,
    required this.scheduledTimes,
    required this.showAll,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final shown = showAll
        ? scheduledTimes
        : scheduledTimes.take(8).toList();

    // Group into rows of 4
    final rows = <String>[];
    for (int i = 0; i < shown.length; i += 4) {
      rows.add(shown.skip(i).take(4).join('  |  '));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Next departure card
        if (nextDeparture != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next bus will depart at',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  nextDeparture!,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),

        // Scheduled times
        if (scheduledTimes.isNotEmpty) ...[
          Text(
            'Scheduled:',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                row,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (scheduledTimes.length > 8)
            GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      showAll ? 'View less' : 'View more',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Icon(
                      showAll
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
        ] else
          Text(
            'No scheduled times available for today.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),

        const SizedBox(height: 8),
      ],
    );
  }
}
