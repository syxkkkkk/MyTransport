import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/transit_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

class RouteDetailsScreen extends StatefulWidget {
  const RouteDetailsScreen({super.key});

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  NearbyStation? _origin;
  NearbyStation? _destination;
  RouteResult?   _result;
  bool _computed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_computed) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _origin      = args['origin']      as NearbyStation?;
      _destination = args['destination'] as NearbyStation?;
    }
    if (_origin != null && _destination != null) {
      _result = TransitService.computeRoute(_origin!, _destination!);
    }
    _computed = true;
  }

  Color _lineColor(String? hex) {
    if (hex == null) return AppColors.primary;
    try { return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16)); }
    catch (_) { return AppColors.primary; }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;

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
        title: Text('Journey Planner',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.primary)),
        centerTitle: true,
      ),

      body: r == null
          ? _buildNoArgs()
          : r.isSameStation
              ? _buildSameStation(r)
              : !r.found
                  ? _buildNoRoute(r)
                  : _buildRoute(r),

      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.map),
    );
  }

  // ── Route found ─────────────────────────────────────────────────────────────

  Widget _buildRoute(RouteResult r) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      children: [
        _SummaryCard(result: r, lineColor: _lineColor),
        const SizedBox(height: 16),
        _JourneyCard(result: r, lineColor: _lineColor),
      ],
    );
  }

  // ── Error states ─────────────────────────────────────────────────────────────

  Widget _buildNoArgs() => _centreMessage(
    Icons.directions_off_outlined,
    'No route data',
    'Go back and select your origin station first.',
  );

  Widget _buildSameStation(RouteResult r) => _centreMessage(
    Icons.location_on_outlined,
    'Already there',
    'Origin and destination are the same station (${r.originName}).',
  );

  Widget _buildNoRoute(RouteResult r) => _centreMessage(
    Icons.route_outlined,
    'No route found',
    'Could not find a route from ${r.originName} to ${r.destName}.\n'
    'These stations may not yet be in the database.',
  );

  Widget _centreMessage(IconData icon, String title, String body) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: AppColors.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.inter(fontSize: 18,
              fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13,
                  color: AppColors.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final RouteResult result;
  final Color Function(String?) lineColor;
  const _SummaryCard({required this.result, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final fareStr = 'RM ${r.fareRM.toStringAsFixed(2)}';
    final minsStr = '${r.totalMinutes} min';

    // Find first line color for the accent
    final firstLine = r.segments
        .where((s) => s.type == SegmentType.ride)
        .firstOrNull;
    final accent = lineColor(firstLine?.lineColor);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Origin → Destination header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _StationLabel(label: 'FROM', name: r.originName),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Icon(Icons.south, size: 16, color: accent),
                ),
                _StationLabel(label: 'TO', name: r.destName),
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(minsStr,
                  style: GoogleFonts.inter(fontSize: 22,
                      fontWeight: FontWeight.w700, color: accent)),
              const SizedBox(height: 2),
              Text(fareStr,
                  style: GoogleFonts.inter(fontSize: 13,
                      color: AppColors.onSurfaceVariant)),
            ]),
          ]),
        ),

        // Transfer count chip
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Wrap(spacing: 8, children: [
            _Chip(
              icon: Icons.swap_horiz,
              label: r.segments.where((s) => s.type == SegmentType.transfer).length == 0
                  ? 'Direct — no transfers'
                  : '${r.segments.where((s) => s.type == SegmentType.transfer).length} transfer(s)',
              color: accent,
            ),
            _Chip(
              icon: Icons.directions_transit,
              label: r.segments.where((s) => s.type == SegmentType.ride)
                  .map((s) => s.lineCode ?? '').join(' + '),
              color: AppColors.onSurfaceVariant,
            ),
          ]),
        ),
      ]),
    );
  }
}

class _StationLabel extends StatelessWidget {
  final String label;
  final String name;
  const _StationLabel({required this.label, required this.name});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 0.8,
          color: AppColors.onSurfaceVariant)),
      const SizedBox(height: 2),
      Text(name, style: GoogleFonts.inter(fontSize: 16,
          fontWeight: FontWeight.w700, color: AppColors.onSurface)),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.inter(fontSize: 12,
            fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// ── Journey steps card ────────────────────────────────────────────────────────

class _JourneyCard extends StatelessWidget {
  final RouteResult result;
  final Color Function(String?) lineColor;
  const _JourneyCard({required this.result, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    final segs = result.segments;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Journey Details', style: GoogleFonts.inter(fontSize: 18,
            fontWeight: FontWeight.w600, color: AppColors.onSurface)),
        const SizedBox(height: 20),
        ...List.generate(segs.length, (i) => _buildStep(segs[i], i < segs.length - 1)),
      ]),
    );
  }

  Widget _buildStep(RouteSegment seg, bool hasLine) {
    switch (seg.type) {
      case SegmentType.ride:
        return _RideStep(seg: seg, lineColor: lineColor(seg.lineColor), hasLine: hasLine);
      case SegmentType.transfer:
        return _TransferStep(seg: seg, lineColor: lineColor(seg.lineColor), hasLine: hasLine);
      case SegmentType.arrive:
        return _ArriveStep(seg: seg);
    }
  }
}

// ── Individual step widgets ───────────────────────────────────────────────────

class _RideStep extends StatelessWidget {
  final RouteSegment seg;
  final Color lineColor;
  final bool hasLine;
  const _RideStep({required this.seg, required this.lineColor, required this.hasLine});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 48,
          child: Column(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: lineColor, shape: BoxShape.circle),
              child: const Icon(Icons.train, size: 22, color: Colors.white),
            ),
            if (hasLine) Expanded(child: Container(width: 2, color: AppColors.outlineVariant)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 8, bottom: hasLine ? 24 : 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(seg.title,
                    style: GoogleFonts.inter(fontSize: 15,
                        fontWeight: FontWeight.w600, color: AppColors.onSurface))),
                if (seg.minutes != null)
                  Text('${seg.minutes} min',
                      style: GoogleFonts.inter(fontSize: 12,
                          color: AppColors.onSurfaceVariant)),
              ]),
              const SizedBox(height: 4),
              Text(seg.subtitle, style: GoogleFonts.inter(fontSize: 13,
                  color: AppColors.onSurfaceVariant)),
              if (seg.stops != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: lineColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.radio_button_checked, size: 14, color: lineColor),
                    const SizedBox(width: 6),
                    Text('${seg.stops} stop${seg.stops! > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(fontSize: 13,
                            color: AppColors.onSurface)),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _TransferStep extends StatelessWidget {
  final RouteSegment seg;
  final Color lineColor;
  final bool hasLine;
  const _TransferStep({required this.seg, required this.lineColor, required this.hasLine});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 48,
          child: Column(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                border: Border.all(color: Colors.amber.shade400, width: 2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.swap_horiz, size: 22, color: Colors.amber.shade700),
            ),
            if (hasLine) Expanded(child: Container(width: 2, color: AppColors.outlineVariant)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 8, bottom: hasLine ? 24 : 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(seg.title, style: GoogleFonts.inter(fontSize: 15,
                  fontWeight: FontWeight.w600, color: AppColors.onSurface)),
              const SizedBox(height: 4),
              Text(seg.subtitle, style: GoogleFonts.inter(fontSize: 13,
                  color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: lineColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(seg.lineCode ?? '',
                      style: GoogleFonts.inter(fontSize: 11,
                          fontWeight: FontWeight.w700, color: lineColor)),
                ),
                const SizedBox(width: 8),
                Text('≈ ${seg.minutes} min walk',
                    style: GoogleFonts.inter(fontSize: 12,
                        color: AppColors.onSurfaceVariant)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ArriveStep extends StatelessWidget {
  final RouteSegment seg;
  const _ArriveStep({required this.seg});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
            color: AppColors.primaryContainer, shape: BoxShape.circle),
        child: const Icon(Icons.flag_outlined,
            size: 22, color: AppColors.onPrimaryContainer),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(seg.title, style: GoogleFonts.inter(fontSize: 15,
                fontWeight: FontWeight.w600, color: AppColors.onSurface)),
            const SizedBox(height: 4),
            Text(seg.subtitle, style: GoogleFonts.inter(fontSize: 13,
                color: AppColors.onSurfaceVariant)),
          ]),
        ),
      ),
    ]);
  }
}
