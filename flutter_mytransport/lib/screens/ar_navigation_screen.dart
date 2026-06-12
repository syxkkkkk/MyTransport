import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ar_service.dart';
import '../theme/app_theme.dart';

/// Pre-launch screen for ARCore Geospatial navigation.
///
/// Accepts optional route arguments as a Map:
///   { 'latitude': double, 'longitude': double, 'stationName': String }
///
/// Falls back to a KL Sentral default so the screen is always usable.
class ARNavigationScreen extends StatefulWidget {
  const ARNavigationScreen({super.key});

  @override
  State<ARNavigationScreen> createState() => _ARNavigationScreenState();
}

class _ARNavigationScreenState extends State<ARNavigationScreen> {
  // Destination — populated from route args or defaults
  double _destLat  = 3.1348;   // KL Sentral
  double _destLng  = 101.6862;
  String _destName = 'KL Sentral';

  bool _checkingSupport = true;
  bool _isSupported     = false;
  bool _isLaunching     = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _destLat  = (args['latitude']    as num?)?.toDouble() ?? _destLat;
      _destLng  = (args['longitude']   as num?)?.toDouble() ?? _destLng;
      _destName = (args['stationName'] as String?) ?? _destName;
    }
    _checkArSupport();
  }

  Future<void> _checkArSupport() async {
    final supported = await ArService.isArCoreAvailable();
    if (mounted) {
      setState(() {
        _isSupported     = supported;
        _checkingSupport = false;
      });
    }
  }

  Future<void> _launchAR() async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);
    try {
      await ArService.launchARNavigation(
        latitude:    _destLat,
        longitude:   _destLng,
        stationName: _destName,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────────
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

          // ── AR grid lines (decorative) ───────────────────────────────────
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _TopBar(onClose: () => Navigator.pop(context)),
                const Spacer(),
                _ARIcon(isSupported: _isSupported, checking: _checkingSupport),
                const SizedBox(height: 32),
                _DestinationCard(name: _destName, lat: _destLat, lng: _destLng),
                const SizedBox(height: 40),
                if (_checkingSupport)
                  _StatusChip(label: 'Checking device compatibility…', isLoading: true)
                else if (_isSupported)
                  _LaunchButton(
                    isLaunching: _isLaunching,
                    onTap: _launchAR,
                  )
                else
                  const _UnsupportedCard(),
                const Spacer(flex: 2),
                _InfoFooter(isSupported: _isSupported),
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
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
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

class _ARIcon extends StatelessWidget {
  final bool isSupported;
  final bool checking;
  const _ARIcon({required this.isSupported, required this.checking});

  @override
  Widget build(BuildContext context) {
    final color = checking
        ? Colors.white38
        : isSupported
            ? const Color(0xFF4285F4)
            : Colors.red.shade400;

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.6), width: 2),
        color: color.withOpacity(0.12),
      ),
      child: Icon(
        checking
            ? Icons.radar
            : isSupported
                ? Icons.view_in_ar_rounded
                : Icons.warning_amber_rounded,
        size: 48,
        color: color,
      ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.train_rounded, color: Color(0xFF4285F4), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Destination',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchButton extends StatelessWidget {
  final bool isLaunching;
  final VoidCallback onTap;
  const _LaunchButton({required this.isLaunching, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLaunching ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A73E8), Color(0xFF4285F4)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4285F4).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: isLaunching
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Start AR Navigation',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isLoading;
  const _StatusChip({required this.label, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedCard extends StatelessWidget {
  const _UnsupportedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 28),
          const SizedBox(height: 10),
          Text(
            'ARCore Not Supported',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade300,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This device does not support ARCore, or Google Play Services for AR is not installed.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InfoFooter extends StatelessWidget {
  final bool isSupported;
  const _InfoFooter({required this.isSupported});

  @override
  Widget build(BuildContext context) {
    if (!isSupported) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _InfoRow(Icons.gps_fixed, 'Requires strong GPS signal outdoors'),
          const SizedBox(height: 6),
          _InfoRow(Icons.streetview, 'Works best in Google Street View areas'),
          const SizedBox(height: 6),
          _InfoRow(Icons.wifi, 'Active internet connection needed'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white30),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white30),
        ),
      ],
    );
  }
}

// ── Decorative grid painter ───────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
