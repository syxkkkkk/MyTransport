import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ar_service.dart';
import '../theme/app_theme.dart';
import 'camera_compass_ar_screen.dart';

/// Pre-launch screen for AR navigation.
///
/// Detects ARCore availability and routes to the best AR mode:
///   - ARCore Geospatial (native) — flagship devices with ARCore installed
///   - Camera + Compass (Flutter)  — all other devices
///
/// Accepts optional route arguments as a Map:
///   { 'latitude': double, 'longitude': double, 'stationName': String }
class ARNavigationScreen extends StatefulWidget {
  const ARNavigationScreen({super.key});

  @override
  State<ARNavigationScreen> createState() => _ARNavigationScreenState();
}

class _ARNavigationScreenState extends State<ARNavigationScreen> {
  double _destLat  = 3.1348;
  double _destLng  = 101.6862;
  String _destName = 'KL Sentral';

  ArCoreStatus _status    = ArCoreStatus.unknown;
  bool _checking          = true;
  bool _isLaunching       = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _destLat  = (args['latitude']    as num?)?.toDouble() ?? _destLat;
      _destLng  = (args['longitude']   as num?)?.toDouble() ?? _destLng;
      _destName = (args['stationName'] as String?)          ?? _destName;
    }
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final status = await ArService.getArCoreStatus();
    if (mounted) setState(() { _status = status; _checking = false; });
  }

  // ── Launch handlers ──────────────────────────────────────────────────────

  Future<void> _launchArCore() async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);
    try {
      await ArService.launchARNavigation(
        latitude: _destLat, longitude: _destLng, stationName: _destName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  void _launchCameraCompass() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraCompassARScreen(
          destLat: _destLat,
          destLng: _destLng,
          stationName: _destName,
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0A1A),
                    const Color(0xFF0D1B3E),
                    const Color(0xFF0A0A1A),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // Content
          SafeArea(
            child: Column(
              children: [
                _TopBar(onClose: () => Navigator.pop(context)),
                const Spacer(),
                _ModeIcon(status: _status, checking: _checking),
                const SizedBox(height: 28),
                _DestinationCard(name: _destName, lat: _destLat, lng: _destLng),
                const SizedBox(height: 32),

                // ── Action area ────────────────────────────────────────
                if (_checking)
                  _StatusChip(label: 'Checking device…', loading: true)

                else if (_status == ArCoreStatus.supportedInstalled)
                  _ActionButton(
                    icon: Icons.view_in_ar_rounded,
                    label: 'Start AR Navigation',
                    sublabel: 'ARCore Geospatial',
                    color: const Color(0xFF4285F4),
                    isLoading: _isLaunching,
                    onTap: _launchArCore,
                  )

                else if (_status == ArCoreStatus.supportedNotInstalled ||
                         _status == ArCoreStatus.supportedApkTooOld) ...[
                  _InstallBanner(apkTooOld: _status == ArCoreStatus.supportedApkTooOld),
                  const SizedBox(height: 16),
                  _ActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Use Camera Mode Instead',
                    sublabel: 'Works without ARCore',
                    color: const Color(0xFF34A853),
                    onTap: _launchCameraCompass,
                  ),
                ]

                else ...[
                  _UnsupportedBanner(),
                  const SizedBox(height: 16),
                  _ActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Start AR Navigation',
                    sublabel: 'Camera + Compass mode',
                    color: const Color(0xFF34A853),
                    onTap: _launchCameraCompass,
                  ),
                ],

                const Spacer(flex: 2),
                if (!_checking) _InfoFooter(status: _status),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              'AR Navigation',
              style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _ModeIcon extends StatelessWidget {
  final ArCoreStatus status;
  final bool checking;
  const _ModeIcon({required this.status, required this.checking});

  @override
  Widget build(BuildContext context) {
    final isGood = status == ArCoreStatus.supportedInstalled;
    final isWarn = status == ArCoreStatus.supportedNotInstalled ||
                   status == ArCoreStatus.supportedApkTooOld;
    final color = checking ? Colors.white38
        : isGood ? const Color(0xFF4285F4)
        : isWarn ? Colors.amber
        : const Color(0xFF34A853);

    final icon = checking    ? Icons.radar
        : isGood             ? Icons.view_in_ar_rounded
        : isWarn             ? Icons.system_update_rounded
        : Icons.camera_alt_rounded;

    return Container(
      width: 88, height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5), width: 2),
        color: color.withOpacity(0.1),
      ),
      child: Icon(icon, size: 44, color: color),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final String name;
  final double lat, lng;
  const _DestinationCard({required this.name, required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.train_rounded, color: Color(0xFF4285F4), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Destination',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
                const SizedBox(height: 2),
                Text(name,
                    style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
                    )),
                const SizedBox(height: 2),
                Text('${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white30)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.85), color],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(label,
                            style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
                            )),
                      ],
                    ),
                    Text(sublabel,
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool loading;
  const _StatusChip({required this.label, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            const SizedBox(
              width: 13, height: 13,
              child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
            ),
            const SizedBox(width: 10),
          ],
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.white60)),
        ],
      ),
    );
  }
}

class _InstallBanner extends StatelessWidget {
  final bool apkTooOld;
  const _InstallBanner({required this.apkTooOld});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update_rounded, color: Colors.amber.shade400, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              apkTooOld
                  ? 'ARCore needs updating. Update "Google Play Services for AR" in the Play Store.'
                  : 'ARCore is not installed. Install "Google Play Services for AR" from the Play Store.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade200),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF34A853).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF34A853).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.camera_alt_rounded, color: Color(0xFF34A853), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This device does not support ARCore. Using Camera + Compass mode instead — works fully offline.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoFooter extends StatelessWidget {
  final ArCoreStatus status;
  const _InfoFooter({required this.status});

  @override
  Widget build(BuildContext context) {
    final rows = status == ArCoreStatus.supportedInstalled
        ? [
            (Icons.gps_fixed, 'Requires strong GPS signal outdoors'),
            (Icons.streetview, 'Works best in Google Street View areas'),
            (Icons.wifi, 'Active internet connection needed'),
          ]
        : [
            (Icons.gps_fixed, 'Requires GPS — go outdoors for best results'),
            (Icons.explore, 'Uses device compass for direction'),
            (Icons.camera_alt, 'Camera permission needed'),
          ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(r.$1, size: 13, color: Colors.white24),
                      const SizedBox(width: 8),
                      Text(r.$2,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.white24)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Decorative grid ───────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.03)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}
