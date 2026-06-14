import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startCompass();
    _startLocation();
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
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

  static const double _fov = 60.0; // degrees visible on each side
  static const double _horizonRatio = 0.48; // horizon at 48% from top

  _MultiPinPainter({
    required this.destinations,
    required this.relativeBearings,
    required this.distances,
    required this.nearest,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final horizonY = size.height * _horizonRatio;
    final cx       = size.width / 2;

    // Draw horizon line
    _drawHorizon(canvas, size, horizonY);

    // Separate in-view and off-screen destinations
    final inView    = <ArDestination>[];
    final offLeft   = <ArDestination>[];
    final offRight  = <ArDestination>[];

    for (final d in destinations) {
      final rb = relativeBearings[d]!;
      if (rb.abs() <= _fov) {
        inView.add(d);
      } else if (rb < 0) {
        offLeft.add(d);
      } else {
        offRight.add(d);
      }
    }

    // Draw in-view pins
    for (final d in inView) {
      final rb     = relativeBearings[d]!;
      final x      = cx + (rb / _fov) * cx;
      final dist   = distances[d]!;
      final isNear = d == nearest;
      _drawPin(canvas, size, x, horizonY, d, dist, isNear);
    }

    // Draw off-screen edge indicators
    if (offLeft.isNotEmpty) _drawEdgeIndicator(canvas, size, horizonY, offLeft, isLeft: true);
    if (offRight.isNotEmpty) _drawEdgeIndicator(canvas, size, horizonY, offRight, isLeft: false);
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

  void _drawEdgeIndicator(Canvas canvas, Size size, double horizonY,
      List<ArDestination> dests, {required bool isLeft}) {
    final x     = isLeft ? 28.0 : size.width - 28.0;
    final color = dests.first.color;

    // Arrow triangle
    final arrowPath = Path();
    if (isLeft) {
      arrowPath
        ..moveTo(x - 10, horizonY)
        ..lineTo(x + 8,  horizonY - 10)
        ..lineTo(x + 8,  horizonY + 10)
        ..close();
    } else {
      arrowPath
        ..moveTo(x + 10, horizonY)
        ..lineTo(x - 8,  horizonY - 10)
        ..lineTo(x - 8,  horizonY + 10)
        ..close();
    }
    canvas.drawPath(arrowPath,
        Paint()..color = color.withOpacity(0.85)..style = PaintingStyle.fill);

    // Count badge
    if (dests.length > 1) {
      _drawText(canvas, '${dests.length}', x, horizonY - 24,
          color: Colors.white70, fontSize: 11, bold: true);
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
