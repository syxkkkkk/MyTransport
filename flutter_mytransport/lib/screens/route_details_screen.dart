import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/transit_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

class RouteDetailsScreen extends StatefulWidget {
  const RouteDetailsScreen({super.key});

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen>
    with TickerProviderStateMixin {
  NearbyStation? _origin;
  NearbyStation? _destination;
  RouteResult?   _result;
  bool _computed = false;

  // ── Live tracking ──────────────────────────────────────────────────────────
  bool _isTracking = false;
  StreamSubscription<Position>? _posSub;

  /// Flat ordered list of all stops across all ride segments.
  List<StationStop> _allStops = [];
  int  _nextStopIdx = 0;          // next stop the user hasn't reached yet
  StationStop? _currentStation;   // the stop we just announced
  bool _showAnnouncement = false;
  Timer? _announcementTimer;

  /// Transfer station — shown when user arrives there.
  String? _pendingTransferStationId;
  StationStop? _arrivedAtTransfer;

  // ── Animation ──────────────────────────────────────────────────────────────
  late final AnimationController _announceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  late final Animation<double> _announceAnim =
      CurvedAnimation(parent: _announceCtrl, curve: Curves.easeOut);

  // ── Expanded stops state ───────────────────────────────────────────────────
  final Set<int> _expandedSegments = {};

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
      _buildStopsList();
    }
    _computed = true;
  }

  void _buildStopsList() {
    if (_result == null) return;
    final stops = <StationStop>[];
    String? xferId;
    for (final seg in _result!.segments) {
      if (seg.type == SegmentType.ride && seg.stopsDetail.isNotEmpty) {
        // Skip first stop of subsequent legs to avoid duplicating transfer station
        final skip = stops.isNotEmpty && seg.stopsDetail.first.id == stops.last.id;
        stops.addAll(skip ? seg.stopsDetail.skip(1) : seg.stopsDetail);
      }
      if (seg.type == SegmentType.transfer) {
        xferId = seg.transferStationId;
      }
    }
    _allStops = stops;
    _pendingTransferStationId = xferId;
  }

  // ── GPS tracking ──────────────────────────────────────────────────────────

  Future<void> _startTracking() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;

    setState(() { _isTracking = true; _nextStopIdx = 1; }); // skip origin

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30,
      ),
    ).listen(_onPosition);
  }

  void _stopTracking() {
    _posSub?.cancel();
    _posSub = null;
    _announcementTimer?.cancel();
    setState(() {
      _isTracking = false;
      _showAnnouncement = false;
      _arrivedAtTransfer = null;
    });
    _announceCtrl.reverse();
  }

  void _onPosition(Position pos) {
    if (_nextStopIdx >= _allStops.length) return;
    final next = _allStops[_nextStopIdx];
    final dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, next.lat, next.lng);

    if (dist < 250) {
      _announceStation(next);
      _nextStopIdx++;

      // Check if this is the transfer station
      if (_pendingTransferStationId != null && next.id == _pendingTransferStationId) {
        setState(() => _arrivedAtTransfer = next);
      }
    }
  }

  void _announceStation(StationStop stop) {
    _announcementTimer?.cancel();
    setState(() {
      _currentStation = stop;
      _showAnnouncement = true;
    });
    _announceCtrl.forward(from: 0);
    _announcementTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _announceCtrl.reverse().then((_) {
          if (mounted) setState(() => _showAnnouncement = false);
        });
      }
    });
  }

  // ── AR Nav at transfer ────────────────────────────────────────────────────

  void _launchArNavForTransfer(StationStop stop) {
    Navigator.pushNamed(context, '/ar-navigation', arguments: {
      'latitude':    stop.lat,
      'longitude':   stop.lng,
      'stationName': stop.name,
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _announcementTimer?.cancel();
    _announceCtrl.dispose();
    super.dispose();
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
            style: GoogleFonts.inter(fontSize: 18,
                fontWeight: FontWeight.w700, color: AppColors.primary)),
        centerTitle: true,
        actions: [
          if (r != null && r.found)
            IconButton(
              icon: Icon(
                _isTracking ? Icons.gps_fixed : Icons.gps_not_fixed,
                color: _isTracking ? Colors.green : AppColors.primary,
              ),
              tooltip: _isTracking ? 'Stop tracking' : 'Start live tracking',
              onPressed: _isTracking ? _stopTracking : _startTracking,
            ),
        ],
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
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          children: [
            _SummaryCard(result: r, lineColor: _lineColor),
            const SizedBox(height: 12),
            // Track Journey banner
            if (!_isTracking)
              _TrackBanner(onStart: _startTracking),
            if (_isTracking)
              _TrackingActiveBanner(
                nextStop: _nextStopIdx < _allStops.length
                    ? _allStops[_nextStopIdx]
                    : null,
                onStop: _stopTracking,
              ),
            const SizedBox(height: 16),
            _JourneyCard(
              result: r,
              lineColor: _lineColor,
              expandedSegments: _expandedSegments,
              onToggleExpand: (i) => setState(() {
                if (_expandedSegments.contains(i)) {
                  _expandedSegments.remove(i);
                } else {
                  _expandedSegments.add(i);
                }
              }),
              passedStops: _allStops.take(_nextStopIdx).map((s) => s.id).toSet(),
            ),
          ],
        ),

        // ── Transfer AR Nav prompt ─────────────────────────────────────────
        if (_arrivedAtTransfer != null)
          _TransferArOverlay(
            stop: _arrivedAtTransfer!,
            onLaunchAr: () => _launchArNavForTransfer(_arrivedAtTransfer!),
            onDismiss: () => setState(() => _arrivedAtTransfer = null),
          ),

        // ── Station announcement banner ───────────────────────────────────
        if (_showAnnouncement && _currentStation != null)
          Positioned(
            top: 0, left: 0, right: 0,
            child: FadeTransition(
              opacity: _announceAnim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
                    .animate(_announceAnim),
                child: _AnnouncementBanner(
                  station: _currentStation!,
                  isTransfer: _currentStation!.id == _pendingTransferStationId,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Error states ─────────────────────────────────────────────────────────────

  Widget _buildNoArgs() => _centreMessage(Icons.directions_off_outlined,
      'No route data', 'Go back and select your origin station first.');
  Widget _buildSameStation(RouteResult r) => _centreMessage(
      Icons.location_on_outlined, 'Already there',
      'Origin and destination are the same station (${r.originName}).');
  Widget _buildNoRoute(RouteResult r) => _centreMessage(Icons.route_outlined,
      'No route found',
      'Could not find a route from ${r.originName} to ${r.destName}.');

  Widget _centreMessage(IconData icon, String title, String body) =>
      Center(child: Padding(
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
      ));
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final RouteResult result;
  final Color Function(String?) lineColor;
  const _SummaryCard({required this.result, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final accent = lineColor(r.segments
        .where((s) => s.type == SegmentType.ride)
        .firstOrNull?.lineColor);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _StationLabel(label: 'FROM', name: r.originName),
              Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Icon(Icons.south, size: 16, color: accent)),
              _StationLabel(label: 'TO', name: r.destName),
            ])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${r.totalMinutes} min',
                  style: GoogleFonts.inter(fontSize: 22,
                      fontWeight: FontWeight.w700, color: accent)),
              const SizedBox(height: 2),
              Text('RM ${r.fareRM.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(fontSize: 13,
                      color: AppColors.onSurfaceVariant)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Wrap(spacing: 8, children: [
            _Chip(icon: Icons.swap_horiz,
              label: r.segments.where((s) => s.type == SegmentType.transfer).isEmpty
                  ? 'Direct — no transfers' : '1 transfer',
              color: accent),
            _Chip(icon: Icons.directions_transit,
              label: r.segments.where((s) => s.type == SegmentType.ride)
                  .map((s) => s.lineCode ?? '').join(' + '),
              color: AppColors.onSurfaceVariant),
          ]),
        ),
      ]),
    );
  }
}

class _StationLabel extends StatelessWidget {
  final String label, name;
  const _StationLabel({required this.label, required this.name});
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.inter(fontSize: 10,
        fontWeight: FontWeight.w700, letterSpacing: 0.8,
        color: AppColors.onSurfaceVariant)),
    const SizedBox(height: 2),
    Text(name, style: GoogleFonts.inter(fontSize: 16,
        fontWeight: FontWeight.w700, color: AppColors.onSurface)),
  ]);
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.inter(fontSize: 12,
          fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}

// ── Track Journey banners ─────────────────────────────────────────────────────

class _TrackBanner extends StatelessWidget {
  final VoidCallback onStart;
  const _TrackBanner({required this.onStart});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onStart,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(children: [
        Icon(Icons.near_me, color: Colors.green.shade700, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text('Tap to start live tracking — get station alerts as you travel',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.green.shade800))),
        Icon(Icons.chevron_right, color: Colors.green.shade700),
      ]),
    ),
  );
}

class _TrackingActiveBanner extends StatelessWidget {
  final StationStop? nextStop;
  final VoidCallback onStop;
  const _TrackingActiveBanner({required this.nextStop, required this.onStop});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.green.shade700,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      const SizedBox(width: 8, height: 8,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Live tracking active',
            style: GoogleFonts.inter(fontSize: 12,
                fontWeight: FontWeight.w700, color: Colors.white)),
        if (nextStop != null)
          Text('Next: ${nextStop!.name}',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
      ])),
      GestureDetector(
        onTap: onStop,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('Stop', style: GoogleFonts.inter(fontSize: 12,
              fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    ]),
  );
}

// ── Journey steps card ────────────────────────────────────────────────────────

class _JourneyCard extends StatelessWidget {
  final RouteResult result;
  final Color Function(String?) lineColor;
  final Set<int> expandedSegments;
  final void Function(int) onToggleExpand;
  final Set<String> passedStops;

  const _JourneyCard({
    required this.result,
    required this.lineColor,
    required this.expandedSegments,
    required this.onToggleExpand,
    required this.passedStops,
  });

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
        ...List.generate(segs.length, (i) {
          final seg = segs[i];
          final hasLine = i < segs.length - 1;
          switch (seg.type) {
            case SegmentType.ride:
              return _RideStep(
                seg: seg,
                lineColor: lineColor(seg.lineColor),
                hasLine: hasLine,
                isExpanded: expandedSegments.contains(i),
                onToggle: () => onToggleExpand(i),
                passedStops: passedStops,
              );
            case SegmentType.transfer:
              return _TransferStep(
                  seg: seg, lineColor: lineColor(seg.lineColor), hasLine: hasLine);
            case SegmentType.arrive:
              return _ArriveStep(seg: seg);
          }
        }),
      ]),
    );
  }
}

// ── Ride step with expandable stops ──────────────────────────────────────────

class _RideStep extends StatelessWidget {
  final RouteSegment seg;
  final Color lineColor;
  final bool hasLine;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Set<String> passedStops;

  const _RideStep({
    required this.seg,
    required this.lineColor,
    required this.hasLine,
    required this.isExpanded,
    required this.onToggle,
    required this.passedStops,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Timeline column
        SizedBox(width: 48, child: Column(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: lineColor, shape: BoxShape.circle),
            child: const Icon(Icons.train, size: 22, color: Colors.white),
          ),
          if (hasLine) Expanded(child: Container(width: 2,
              color: AppColors.outlineVariant)),
        ])),
        const SizedBox(width: 14),

        // Content
        Expanded(child: Padding(
          padding: EdgeInsets.only(top: 8, bottom: hasLine ? 24 : 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Line name + time
            Row(children: [
              Expanded(child: Text(seg.title,
                  style: GoogleFonts.inter(fontSize: 15,
                      fontWeight: FontWeight.w600, color: AppColors.onSurface))),
              if (seg.minutes != null)
                Text('${seg.minutes} min',
                    style: GoogleFonts.inter(fontSize: 12,
                        color: AppColors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 2),
            Text(seg.subtitle, style: GoogleFonts.inter(fontSize: 13,
                color: AppColors.onSurfaceVariant)),

            // Platform indicator
            if (seg.boardingPlatform != null &&
                seg.boardingPlatform!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: lineColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: lineColor.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.subway_outlined, size: 13, color: lineColor),
                  const SizedBox(width: 5),
                  Text(seg.boardingPlatform!,
                      style: GoogleFonts.inter(fontSize: 12,
                          fontWeight: FontWeight.w600, color: lineColor)),
                ]),
              ),
            ],

            // Stops chip (tappable to expand)
            if (seg.stops != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onToggle,
                child: Container(
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
                    const SizedBox(width: 6),
                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16, color: lineColor),
                    const SizedBox(width: 2),
                    Text(isExpanded ? 'Hide' : 'Details',
                        style: GoogleFonts.inter(fontSize: 11,
                            fontWeight: FontWeight.w600, color: lineColor)),
                  ]),
                ),
              ),
            ],

            // Expanded station list
            if (isExpanded && seg.stopsDetail.isNotEmpty) ...[
              const SizedBox(height: 8),
              _StopsList(
                stops: seg.stopsDetail,
                lineColor: lineColor,
                passedStops: passedStops,
              ),
            ],
          ]),
        )),
      ]),
    );
  }
}

// ── Stops detail list ─────────────────────────────────────────────────────────

class _StopsList extends StatelessWidget {
  final List<StationStop> stops;
  final Color lineColor;
  final Set<String> passedStops;
  const _StopsList({required this.stops, required this.lineColor,
      required this.passedStops});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: lineColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: lineColor.withOpacity(0.15)),
      ),
      child: Column(
        children: List.generate(stops.length, (i) {
          final stop = stops[i];
          final isFirst = i == 0;
          final isLast  = i == stops.length - 1;
          final passed  = passedStops.contains(stop.id);
          final isCurrent = !passed && (i == 0 ||
              passedStops.contains(stops[i - 1].id));

          return IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Dot + line column
              SizedBox(width: 20, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, children: [
                const SizedBox(height: 4),
                Container(
                  width: isCurrent ? 12 : (isFirst || isLast ? 10 : 8),
                  height: isCurrent ? 12 : (isFirst || isLast ? 10 : 8),
                  decoration: BoxDecoration(
                    color: passed ? lineColor.withOpacity(0.4)
                        : (isCurrent ? lineColor : lineColor.withOpacity(0.25)),
                    shape: BoxShape.circle,
                    border: isCurrent ? Border.all(color: lineColor, width: 2) : null,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2,
                      color: lineColor.withOpacity(0.2),
                      margin: const EdgeInsets.symmetric(vertical: 2))),
              ])),
              const SizedBox(width: 10),
              // Station name
              Expanded(child: Padding(
                padding: EdgeInsets.only(
                    top: 0, bottom: isLast ? 0 : 10),
                child: Row(children: [
                  Expanded(child: Text(stop.name,
                      style: GoogleFonts.inter(
                        fontSize: isFirst || isLast ? 13 : 12,
                        fontWeight: isFirst || isLast || isCurrent
                            ? FontWeight.w600 : FontWeight.w400,
                        color: passed
                            ? AppColors.onSurfaceVariant
                            : (isCurrent ? lineColor : AppColors.onSurface),
                      ))),
                  if (passed)
                    Icon(Icons.check_circle, size: 14,
                        color: lineColor.withOpacity(0.5)),
                  if (isCurrent && !isFirst)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('You are here',
                          style: GoogleFonts.inter(fontSize: 9,
                              fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                ]),
              )),
            ]),
          );
        }),
      ),
    );
  }
}

// ── Transfer step ─────────────────────────────────────────────────────────────

class _TransferStep extends StatelessWidget {
  final RouteSegment seg;
  final Color lineColor;
  final bool hasLine;
  const _TransferStep({required this.seg, required this.lineColor,
      required this.hasLine});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 48, child: Column(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              border: Border.all(color: Colors.amber.shade400, width: 2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.swap_horiz, size: 22, color: Colors.amber.shade700),
          ),
          if (hasLine) Expanded(child: Container(width: 2,
              color: AppColors.outlineVariant)),
        ])),
        const SizedBox(width: 14),
        Expanded(child: Padding(
          padding: EdgeInsets.only(top: 8, bottom: hasLine ? 24 : 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(seg.title, style: GoogleFonts.inter(fontSize: 15,
                fontWeight: FontWeight.w600, color: AppColors.onSurface)),
            const SizedBox(height: 4),
            Text(seg.subtitle, style: GoogleFonts.inter(fontSize: 13,
                color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(children: [
              if (seg.boardingPlatform != null && seg.boardingPlatform!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: lineColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.subway_outlined, size: 12, color: lineColor),
                    const SizedBox(width: 4),
                    Text(seg.boardingPlatform!,
                        style: GoogleFonts.inter(fontSize: 11,
                            fontWeight: FontWeight.w700, color: lineColor)),
                  ]),
                ),
              if (seg.boardingPlatform != null && seg.boardingPlatform!.isNotEmpty)
                const SizedBox(width: 8),
              Text('≈ ${seg.minutes} min walk',
                  style: GoogleFonts.inter(fontSize: 12,
                      color: AppColors.onSurfaceVariant)),
            ]),
          ]),
        )),
      ]),
    );
  }
}

// ── Arrive step ───────────────────────────────────────────────────────────────

class _ArriveStep extends StatelessWidget {
  final RouteSegment seg;
  const _ArriveStep({required this.seg});
  @override
  Widget build(BuildContext context) => Row(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 48, height: 48,
        decoration: const BoxDecoration(
            color: AppColors.primaryContainer, shape: BoxShape.circle),
        child: const Icon(Icons.flag_outlined, size: 22,
            color: AppColors.onPrimaryContainer)),
    const SizedBox(width: 14),
    Expanded(child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(seg.title, style: GoogleFonts.inter(fontSize: 15,
            fontWeight: FontWeight.w600, color: AppColors.onSurface)),
        const SizedBox(height: 4),
        Text(seg.subtitle, style: GoogleFonts.inter(fontSize: 13,
            color: AppColors.onSurfaceVariant)),
      ]),
    )),
  ]);
}

// ── Station announcement banner ───────────────────────────────────────────────

class _AnnouncementBanner extends StatelessWidget {
  final StationStop station;
  final bool isTransfer;
  const _AnnouncementBanner({required this.station, required this.isTransfer});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isTransfer ? Colors.amber.shade800 : Colors.green.shade700,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Icon(isTransfer ? Icons.swap_horiz : Icons.train,
              color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(isTransfer ? 'Transfer Station' : 'Now arriving',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
            Text(station.name,
                style: GoogleFonts.inter(fontSize: 15,
                    fontWeight: FontWeight.w700, color: Colors.white)),
            if (isTransfer)
              Text('Get ready to change trains',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
          ])),
          const Icon(Icons.volume_up, color: Colors.white70, size: 18),
        ]),
      ),
    );
  }
}

// ── Transfer AR Nav overlay ───────────────────────────────────────────────────

class _TransferArOverlay extends StatelessWidget {
  final StationStop stop;
  final VoidCallback onLaunchAr;
  final VoidCallback onDismiss;
  const _TransferArOverlay({required this.stop, required this.onLaunchAr,
      required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.black12,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF8E1), shape: BoxShape.circle),
            child: const Icon(Icons.swap_horiz, color: Color(0xFFF57F17), size: 28),
          ),
          const SizedBox(height: 12),
          Text('You\'ve arrived at ${stop.name}!',
              style: GoogleFonts.inter(fontSize: 17,
                  fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Use AR Navigation to find the correct platform for your next train.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onLaunchAr,
              icon: const Icon(Icons.view_in_ar_rounded),
              label: Text('Open AR Nav — Find Platform',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onDismiss,
            child: Text('Dismiss', style: GoogleFonts.inter(color: Colors.black38)),
          ),
        ]),
      ),
    );
  }
}
