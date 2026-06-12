import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

/// Camera + Compass AR navigation screen.
///
/// Works on ALL Android devices — no ARCore required.
/// Uses live camera feed, GPS position, and device compass to
/// overlay a directional arrow pointing toward the destination.
class CameraCompassARScreen extends StatefulWidget {
  final double destLat;
  final double destLng;
  final String stationName;

  const CameraCompassARScreen({
    super.key,
    required this.destLat,
    required this.destLng,
    required this.stationName,
  });

  @override
  State<CameraCompassARScreen> createState() => _CameraCompassARScreenState();
}

class _CameraCompassARScreenState extends State<CameraCompassARScreen> {
  CameraController? _camCtrl;
  bool _camReady   = false;
  String? _camError;

  double _compassHeading = 0;   // degrees from North, 0–360
  double _userLat = 0, _userLng = 0;
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startCompass();
    _startLocation();
  }

  // ── Camera ──────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _camError = 'No camera found on this device');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      if (!mounted) return;
      setState(() {
        _camCtrl  = ctrl;
        _camReady = true;
      });
    } catch (e) {
      if (mounted) setState(() => _camError = 'Camera error: $e');
    }
  }

  // ── Compass ──────────────────────────────────────────────────────────────

  void _startCompass() {
    FlutterCompass.events?.listen((event) {
      if (mounted && event.heading != null) {
        setState(() => _compassHeading = event.heading!);
      }
    });
  }

  // ── GPS ──────────────────────────────────────────────────────────────────

  Future<void> _startLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).listen((pos) {
      if (mounted) {
        setState(() {
          _userLat     = pos.latitude;
          _userLng     = pos.longitude;
          _hasLocation = true;
        });
      }
    });
  }

  // ── Navigation math ──────────────────────────────────────────────────────

  /// Compass bearing from user to destination (0–360, 0 = North).
  double get _bearingToDest => Geolocator.bearingBetween(
      _userLat, _userLng, widget.destLat, widget.destLng);

  /// Angle the arrow should rotate: 0 = straight ahead, 90 = turn right.
  double get _relativeBearing =>
      (_bearingToDest - _compassHeading + 360) % 360;

  /// Straight-line distance in metres.
  double get _distanceMetres => Geolocator.distanceBetween(
      _userLat, _userLng, widget.destLat, widget.destLng);

  String get _distanceLabel {
    final d = _distanceMetres;
    return d < 1000 ? '${d.toStringAsFixed(0)} m' : '${(d / 1000).toStringAsFixed(1)} km';
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera background ──────────────────────────────────────────
          if (_camReady && _camCtrl != null)
            Positioned.fill(child: CameraPreview(_camCtrl!))
          else if (_camError != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black87,
                child: Center(
                  child: Text(_camError!,
                      style: GoogleFonts.inter(color: Colors.white54)),
                ),
              ),
            )
          else
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white38),
                ),
              ),
            ),

          // ── AR arrow ──────────────────────────────────────────────────
          if (_hasLocation)
            Positioned.fill(
              child: CustomPaint(
                painter: _ArrowPainter(angleDeg: _relativeBearing),
              ),
            ),

          // ── Horizon line ──────────────────────────────────────────────
          if (_hasLocation)
            Positioned.fill(
              child: CustomPaint(painter: _HorizonPainter()),
            ),

          // ── Top bar ───────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _TopBar(
              stationName: widget.stationName,
              onClose: () => Navigator.pop(context),
            ),
          ),

          // ── Acquiring status ──────────────────────────────────────────
          if (!_hasLocation)
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white54, strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Acquiring GPS…',
                          style: GoogleFonts.inter(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Bottom HUD ────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomHUD(
              distanceLabel: _hasLocation ? _distanceLabel : '--',
              heading: _compassHeading,
              mode: 'Camera mode',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
    super.dispose();
  }
}

// ── Arrow painter ─────────────────────────────────────────────────────────────

class _ArrowPainter extends CustomPainter {
  final double angleDeg;
  const _ArrowPainter({required this.angleDeg});

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width  / 2;
    final cy   = size.height / 2;
    final s    = size.shortestSide * 0.18;
    final rad  = angleDeg * pi / 180;

    final fill = Paint()
      ..color = const Color(0xFF4285F4).withOpacity(0.85)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final glow = Paint()
      ..color = const Color(0xFF4285F4).withOpacity(0.25)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rad);

    final path = Path()
      ..moveTo(0,            -s)
      ..lineTo( s * 0.55,    s * 0.25)
      ..lineTo( s * 0.22,    s * 0.05)
      ..lineTo( s * 0.22,    s * 0.65)
      ..lineTo(-s * 0.22,    s * 0.65)
      ..lineTo(-s * 0.22,    s * 0.05)
      ..lineTo(-s * 0.55,    s * 0.25)
      ..close();

    canvas.drawPath(path, glow);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.angleDeg != angleDeg;
}

// ── Horizon line painter ─────────────────────────────────────────────────────

class _HorizonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.5;
    const y = 0.5;
    canvas.drawLine(
      Offset(size.width * 0.05, size.height * y),
      Offset(size.width * 0.40, size.height * y),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.60, size.height * y),
      Offset(size.width * 0.95, size.height * y),
      paint,
    );
    // Centre crosshair
    final cp = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.5;
    final cx = size.width / 2, cy = size.height / 2;
    canvas.drawLine(Offset(cx - 12, cy), Offset(cx + 12, cy), cp);
    canvas.drawLine(Offset(cx, cy - 12), Offset(cx, cy + 12), cp);
  }

  @override
  bool shouldRepaint(_HorizonPainter old) => false;
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
              child: Text(
                stationName,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
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
  final String distanceLabel;
  final double heading;
  final String mode;
  const _BottomHUD({
    required this.distanceLabel,
    required this.heading,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.black.withOpacity(0.65),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  distanceLabel,
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4285F4),
                  ),
                ),
                Text(
                  'to destination',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${heading.toStringAsFixed(0)}°',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  mode,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white30),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
