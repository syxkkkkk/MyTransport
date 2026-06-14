import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ── AR destination model ──────────────────────────────────────────────────────

class ArDestination {
  final String label;     // "Platform 1"
  final String sublabel;  // "towards Gombak"
  final double lat;
  final double lng;
  final Color color;

  const ArDestination({
    required this.label,
    required this.sublabel,
    required this.lat,
    required this.lng,
    required this.color,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CameraCompassARScreen extends StatefulWidget {
  final String stationName;
  final List<ArDestination> destinations;

  const CameraCompassARScreen({
    super.key,
    required this.stationName,
    required this.destinations,
  });

  @override
  State<CameraCompassARScreen> createState() => _CameraCompassARScreenState();
}

class _CameraCompassARScreenState extends State<CameraCompassARScreen> {
  CameraController? _camCtrl;
  bool _camReady  = false;
  String? _camError;

  double _compassHeading = 0;
  double _userLat = 0, _userLng = 0;
  bool _hasLocation = false;

  /// Device pitch in degrees.
  /// 0 = phone held upright, +90 = tilted back (camera pointing up),
  /// -90 = tilted forward (camera pointing down).
  double _devicePitch = 0.0;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startCompass();
    _startLocation();
    _startPitch();
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
    _accelSub?.cancel();
    super.dispose();
  }

  // ── Camera ──────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _camError = 'No camera found');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(back, ResolutionPreset.high,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await ctrl.initialize();
      if (!mounted) return;
      setState(() { _camCtrl = ctrl; _camReady = true; });
    } catch (e) {
      if (mounted) setState(() => _camError = 'Camera error: $e');
    }
  }

  // ── Compass ─────────────────────────────────────────────────────────────────

  void _startCompass() {
    FlutterCompass.events?.listen((e) {
      if (mounted && e.heading != null) {
        setState(() => _compassHeading = e.heading!);
      }
    });
  }

  // ── Pitch (tilt) via accelerometer ───────────────────────────────────────────

  void _startPitch() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 80),
    ).listen((AccelerometerEvent e) {
      if (!mounted) return;
      // pitch: 0 = upright, +90 = tilted back (camera up), -90 = tilted forward (camera down)
      final pitch = atan2(-e.z, e.y) * 180 / pi;
      if ((pitch - _devicePitch).abs() > 0.5) {
        setState(() => _devicePitch = pitch);
      }
    });
  }

  // ── GPS ─────────────────────────────────────────────────────────────────────

  Future<void> _startLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

    // 1 — Use last known position immediately so pins show without waiting.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null && mounted) {
      setState(() { _userLat = last.latitude; _userLng = last.longitude; _hasLocation = true; });
    }

    // 2 — Stream for live updates (refines position as GPS locks on).
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 2),
    ).listen((pos) {
      if (mounted) setState(() { _userLat = pos.latitude; _userLng = pos.longitude; _hasLocation = true; });
    });
  }

  // ── Math helpers ─────────────────────────────────────────────────────────────

  double _bearingTo(ArDestination d) =>
      Geolocator.bearingBetween(_userLat, _userLng, d.lat, d.lng);

  double _distanceTo(ArDestination d) =>
      Geolocator.distanceBetween(_userLat, _userLng, d.lat, d.lng);

  /// Relative bearing: 0 = straight ahead, +90 = right, -90 = left.
  double _relativeBearing(ArDestination d) {
    double r = (_bearingTo(d) - _compassHeading + 360) % 360;
    if (r > 180) r -= 360;
    return r;
  }

  /// Nearest destination by distance.
  ArDestination get _nearest => widget.destinations.reduce(
      (a, b) => _distanceTo(a) <= _distanceTo(b) ? a : b);

  String _distLabel(double metres) => metres < 1000
      ? '${metres.toStringAsFixed(0)} m'
      : '${(metres / 1000).toStringAsFixed(1)} km';

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final nearest = _hasLocation ? _nearest : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera background
          if (_camReady && _camCtrl != null)
            Positioned.fill(child: CameraPreview(_camCtrl!))
          else if (_camError != null)
            Positioned.fill(child: ColoredBox(
              color: Colors.black87,
              child: Center(child: Text(_camError!, style: GoogleFonts.inter(color: Colors.white54))),
            ))
          else
            const Positioned.fill(child: ColoredBox(
              color: Colors.black,
              child: Center(child: CircularProgressIndicator(color: Colors.white38)),
            )),

          // Multi-pin AR overlay
          if (_hasLocation)
            Positioned.fill(
              child: CustomPaint(
                painter: _MultiPinPainter(
                  destinations: widget.destinations,
                  relativeBearings: {
                    for (final d in widget.destinations) d: _relativeBearing(d),
                  },
                  distances: {
                    for (final d in widget.destinations) d: _distanceTo(d),
                  },
                  nearest: nearest,
                  devicePitch: _devicePitch,
                ),
              ),
            ),

          // GPS acquiring — small banner only, does NOT block the AR view
          if (!_hasLocation)
            Positioned(
              top: 80, left: 24, right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text('Acquiring GPS — go outdoors for best results',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: _TopBar(stationName: widget.stationName, onClose: () => Navigator.pop(context)),
          ),

          // Bottom HUD
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomHUD(
              nearest: nearest,
              distance: nearest != null ? _distLabel(_distanceTo(nearest)) : '--',
              heading: _compassHeading,
              totalPins: widget.destinations.length,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Multi-pin AR painter ──────────────────────────────────────────────────────
//
// Field of view assumed: ±60° visible on screen (horizontal).
// Pins within ±60° are drawn on the horizon line.
// Pins outside ±60° show as edge arrows with labels.

class _MultiPinPainter extends CustomPainter {
  final List<ArDestination> destinations;
  final Map<ArDestination, double> relativeBearings; // -180 to +180
  final Map<ArDestination, double> distances;         // metres
  final ArDestination? nearest;
  final double devicePitch; // degrees: 0=upright, +90=tilted back, -90=tilted fwd

  static const double _hFov     = 60.0;  // horizontal FOV (each side)
  static const double _vFov     = 25.0;  // vertical FOV (each side, ~50° total)
  static const double _horizonR = 0.48;  // horizon at 48% from top when upright

  _MultiPinPainter({
    required this.destinations,
    required this.relativeBearings,
    required this.distances,
    required this.nearest,
    this.devicePitch = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Base horizon Y (when phone is upright).
    // Shifts up when tilting back (camera pointing up) and down when tilting forward.
    // pitch > 0 → camera tilted up → horizon appears lower on screen → horizonY increases.
    final horizonY = (size.height * _horizonR) + (devicePitch / _vFov) * cy;

    // Draw horizon line
    _drawHorizon(canvas, size, horizonY.clamp(20.0, size.height - 20.0));

    // Classify each destination
    final inView   = <ArDestination>[];
    final offLeft  = <ArDestination>[];
    final offRight = <ArDestination>[];
    final offUp    = <ArDestination>[];
    final offDown  = <ArDestination>[];

    for (final d in destinations) {
      final rb = relativeBearings[d]!;
      final pinY = horizonY;  // horizontal target, vertical varies by pitch

      if (rb.abs() > _hFov) {
        if (rb < 0) offLeft.add(d); else offRight.add(d);
      } else if (pinY < -20) {
        offUp.add(d);
      } else if (pinY > size.height + 20) {
        offDown.add(d);
      } else {
        inView.add(d);
      }
    }

    // Draw in-view pins
    for (final d in inView) {
      final rb   = relativeBearings[d]!;
      final x    = cx + (rb / _hFov) * cx;
      final dist = distances[d]!;
      _drawPin(canvas, size, x, horizonY, d, dist, d == nearest);
    }

    // Edge arrows — left/right (badge sits at horizonY so it lines up with where pin would be)
    if (offLeft.isNotEmpty)  _drawEdgeArrow(canvas, size, offLeft,  side: 'left',   y: horizonY);
    if (offRight.isNotEmpty) _drawEdgeArrow(canvas, size, offRight, side: 'right',  y: horizonY);
    // Edge arrows — up/down (pin out of vertical FOV)
    if (offUp.isNotEmpty)    _drawEdgeArrow(canvas, size, offUp,    side: 'top',    y: 0);
    if (offDown.isNotEmpty)  _drawEdgeArrow(canvas, size, offDown,  side: 'bottom', y: size.height);
  }

  void _drawHorizon(Canvas canvas, Size size, double y) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(size.width * 0.05, y), Offset(size.width * 0.40, y), paint);
    canvas.drawLine(Offset(size.width * 0.60, y), Offset(size.width * 0.95, y), paint);

    // Crosshair
    final cp = Paint()..color = Colors.white.withOpacity(0.25)..strokeWidth = 1.5;
    final cx = size.width / 2;
    canvas.drawLine(Offset(cx - 14, y), Offset(cx + 14, y), cp);
    canvas.drawLine(Offset(cx, y - 14), Offset(cx, y + 14), cp);
  }

  void _drawPin(Canvas canvas, Size size, double x, double horizonY,
      ArDestination d, double dist, bool isNearest) {
    final color  = d.color;
    final radius = isNearest ? 18.0 : 13.0;

    // Glow
    if (isNearest) {
      canvas.drawCircle(
        Offset(x, horizonY),
        radius + 10,
        Paint()
          ..color = color.withOpacity(0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // Stem line from horizon down to pin
    canvas.drawLine(
      Offset(x, horizonY),
      Offset(x, horizonY + radius + 4),
      Paint()..color = color.withOpacity(0.6)..strokeWidth = 2,
    );

    // Pin circle
    canvas.drawCircle(Offset(x, horizonY + radius + 4), radius,
        Paint()..color = color.withOpacity(isNearest ? 0.95 : 0.75)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(x, horizonY + radius + 4), radius,
        Paint()..color = Colors.white.withOpacity(0.9)..style = PaintingStyle.stroke..strokeWidth = isNearest ? 2.5 : 1.5);

    // Train icon (simple dot)
    canvas.drawCircle(Offset(x, horizonY + radius + 4), radius * 0.35,
        Paint()..color = Colors.white..style = PaintingStyle.fill);

    // Label above horizon
    _drawText(canvas, d.label, x, horizonY - 10,
        color: Colors.white, fontSize: isNearest ? 14 : 12, bold: isNearest);
    _drawText(canvas, d.sublabel, x, horizonY - 10 - (isNearest ? 20 : 17),
        color: color, fontSize: isNearest ? 11 : 10, bold: false);

    // Distance below pin
    _drawText(canvas, _fmtDist(dist), x, horizonY + radius * 2 + 18,
        color: Colors.white70, fontSize: 11, bold: false);
  }

  /// Draws a large, prominent edge arrow at the screen border pointing toward
  /// off-screen destinations.
  /// [side] is one of 'left', 'right', 'top', 'bottom'.
  /// [y] is the vertical position hint (used only for left/right).
  void _drawEdgeArrow(Canvas canvas, Size size,
      List<ArDestination> dests, {required String side, required double y}) {
    const double arrowHalf = 22.0;  // half-width of the arrow head
    const double arrowLen  = 44.0;  // length of the arrow head
    const double margin    = 14.0;  // distance from screen edge
    const double badgeR    = 26.0;  // badge circle radius

    final color = dests.first.color;
    final label = dests.length == 1
        ? dests.first.label
        : '${dests.length} pins';

    // ── Position & arrow geometry ─────────────────────────────────────────────
    late double bx, by;           // badge centre
    late List<Offset> triangle;   // arrow head vertices

    switch (side) {
      case 'left':
        bx = margin + badgeR;
        by = y.clamp(badgeR + margin, size.height - badgeR - margin);
        triangle = [
          Offset(bx - badgeR - arrowLen, by),        // tip
          Offset(bx - badgeR,            by - arrowHalf),
          Offset(bx - badgeR,            by + arrowHalf),
        ];
        break;
      case 'right':
        bx = size.width - margin - badgeR;
        by = y.clamp(badgeR + margin, size.height - badgeR - margin);
        triangle = [
          Offset(bx + badgeR + arrowLen, by),        // tip
          Offset(bx + badgeR,            by - arrowHalf),
          Offset(bx + badgeR,            by + arrowHalf),
        ];
        break;
      case 'top':
        bx = size.width / 2;
        by = margin + badgeR;
        triangle = [
          Offset(bx,              by - badgeR - arrowLen), // tip
          Offset(bx - arrowHalf, by - badgeR),
          Offset(bx + arrowHalf, by - badgeR),
        ];
        break;
      default: // bottom
        bx = size.width / 2;
        by = size.height - margin - badgeR;
        triangle = [
          Offset(bx,              by + badgeR + arrowLen), // tip
          Offset(bx - arrowHalf, by + badgeR),
          Offset(bx + arrowHalf, by + badgeR),
        ];
    }

    // ── Glow behind arrow ────────────────────────────────────────────────────
    final glowPaint = Paint()
      ..color = color.withOpacity(0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(Offset(bx, by), badgeR + 12, glowPaint);

    // ── Arrow triangle ───────────────────────────────────────────────────────
    final arrowPath = Path()
      ..moveTo(triangle[0].dx, triangle[0].dy)
      ..lineTo(triangle[1].dx, triangle[1].dy)
      ..lineTo(triangle[2].dx, triangle[2].dy)
      ..close();
    canvas.drawPath(arrowPath,
        Paint()..color = color.withOpacity(0.95)..style = PaintingStyle.fill);
    canvas.drawPath(arrowPath,
        Paint()
          ..color = Colors.white.withOpacity(0.70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

    // ── Badge circle ─────────────────────────────────────────────────────────
    canvas.drawCircle(Offset(bx, by), badgeR,
        Paint()..color = color.withOpacity(0.92)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(bx, by), badgeR,
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);

    // ── Label inside badge ───────────────────────────────────────────────────
    _drawText(canvas, label, bx, by,
        color: Colors.white, fontSize: 11, bold: true);

    // ── Distance tag beside badge ────────────────────────────────────────────
    if (dests.length == 1) {
      final dist = distances[dests.first];
      if (dist != null) {
        final distStr = _fmtDist(dist);
        // Place distance label on the inward side of the badge
        final double tx, ty;
        switch (side) {
          case 'left':   tx = bx + badgeR + 34; ty = by; break;
          case 'right':  tx = bx - badgeR - 34; ty = by; break;
          case 'top':    tx = bx;               ty = by + badgeR + 14; break;
          default:       tx = bx;               ty = by - badgeR - 14;
        }
        _drawText(canvas, distStr, tx, ty,
            color: Colors.white70, fontSize: 12, bold: false);
      }
    }
  }

  void _drawText(Canvas canvas, String text, double cx, double cy,
      {required Color color, required double fontSize, required bool bold}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 140);
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  String _fmtDist(double m) =>
      m < 1000 ? '${m.toStringAsFixed(0)}m' : '${(m / 1000).toStringAsFixed(1)}km';

  @override
  bool shouldRepaint(_MultiPinPainter old) => true;
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String stationName;
  final VoidCallback onClose;
  const _TopBar({required this.stationName, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.black.withOpacity(0.6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: onClose,
            ),
            Expanded(
              child: Text(stationName,
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

// ── Bottom HUD ────────────────────────────────────────────────────────────────

class _BottomHUD extends StatelessWidget {
  final ArDestination? nearest;
  final String distance;
  final double heading;
  final int totalPins;

  const _BottomHUD({
    required this.nearest,
    required this.distance,
    required this.heading,
    required this.totalPins,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.black.withOpacity(0.70),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Nearest pin info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (nearest != null) ...[
                    Row(
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                              color: nearest!.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(nearest!.label,
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(nearest!.sublabel,
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
                  ],
                  const SizedBox(height: 6),
                  Text(distance,
                      style: GoogleFonts.inter(
                          fontSize: 30, fontWeight: FontWeight.w700,
                          color: nearest?.color ?? const Color(0xFF4285F4))),
                  Text('to nearest pin  ·  $totalPins pins total',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white30)),
                ],
              ),
            ),

            // Compass
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${heading.toStringAsFixed(0)}°',
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white60)),
                Text(_compassDir(heading),
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white30)),
                const SizedBox(height: 2),
                Text('Camera AR', style: GoogleFonts.inter(fontSize: 10, color: Colors.white24)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _compassDir(double h) {
    const dirs = ['N','NE','E','SE','S','SW','W','NW','N'];
    return dirs[((h + 22.5) / 45).floor() % 8];
  }
}
