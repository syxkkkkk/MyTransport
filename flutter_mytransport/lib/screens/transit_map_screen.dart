import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

class TransitMapScreen extends StatefulWidget {
  const TransitMapScreen({super.key});

  @override
  State<TransitMapScreen> createState() => _TransitMapScreenState();
}

class _TransitMapScreenState extends State<TransitMapScreen> {
  final TransformationController _transformCtrl = TransformationController();
  bool _showHint = true;

  @override
  void initState() {
    super.initState();
    // Dismiss hint after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformCtrl.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rail Transit Map',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              'Klang Valley Integrated Network',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map, color: AppColors.primary),
            tooltip: 'Reset zoom',
            onPressed: _resetZoom,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Zoomable/pannable map image ──────────────────────────────────
          InteractiveViewer(
            transformationController: _transformCtrl,
            minScale: 0.5,
            maxScale: 6.0,
            boundaryMargin: const EdgeInsets.all(80),
            child: Center(
              child: Image.asset(
                'assets/images/transit_map.jpg',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),

          // ── Pinch-to-zoom hint ───────────────────────────────────────────
          if (_showHint)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showHint ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pinch, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Pinch to zoom · Drag to pan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Reset zoom FAB hint ──────────────────────────────────────────
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _resetZoom,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
              tooltip: 'Reset zoom',
              child: const Icon(Icons.zoom_out_map, size: 20),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.map),
    );
  }
}
