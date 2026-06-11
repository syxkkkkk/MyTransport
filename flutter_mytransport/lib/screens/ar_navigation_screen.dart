import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class ARNavigationScreen extends StatefulWidget {
  const ARNavigationScreen({super.key});

  @override
  State<ARNavigationScreen> createState() => _ARNavigationScreenState();
}

class _ARNavigationScreenState extends State<ARNavigationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrowCtrl;
  late final Animation<double> _arrowOffset;
  late final Animation<double> _arrowOpacity;
  static const double _progressValue = 0.25;

  static const String _bgUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAu85AV9lXuMTvTcGbsbswqGGk2SFnWPQgGjBBh4X1cX76glxmFcipDhkwExRCTu9cxAsqNNF4nN0_4bh-PcdToIkmyI0fcAim7X3GZVxlKtay7p6o09jH4CzFAxgXJpB73JlnvTxp-semeXMuAZyOMKabu5IeuQLU5YYIPUiVynWnNYa51O9HNMAyZStPacfytAOmqn937yYFxMhb7dYjGYyiSZ-IXvBdu2daxUj9P4efItG2fzCNAYmfQor7UIeeZmIBD-90buH0';

  @override
  void initState() {
    super.initState();
    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _arrowOpacity = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut),
    );
    _arrowOffset = Tween<double>(begin: 0, end: -18).animate(
      CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _arrowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera / Street view background
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: _bgUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: Colors.black87,
                child: const Center(
                  child: Icon(Icons.camera_alt_outlined, size: 80, color: Colors.white30),
                ),
              ),
            ),
          ),

          // Animated AR arrow overlay
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.22,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _arrowCtrl,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, _arrowOffset.value),
                  child: Opacity(
                    opacity: _arrowOpacity.value,
                    child: _ARArrow(),
                  ),
                ),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _TopBar(onClose: () => Navigator.pop(context)),
            ),
          ),

          // Direction card
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 12,
            left: 16,
            right: 16,
            child: const _DirectionCard(),
          ),

          // Side action buttons
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(child: _SideButtons()),
          ),

          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomPanel(
              onProgressTap: () => Navigator.pushNamed(context, '/trip-summary'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ARArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(80, 140),
      painter: _ArrowPainter(),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF004D99).withOpacity(0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height * 0.45)
      ..lineTo(size.width * 0.65, size.height * 0.45)
      ..lineTo(size.width * 0.65, size.height)
      ..lineTo(size.width * 0.35, size.height)
      ..lineTo(size.width * 0.35, size.height * 0.45)
      ..lineTo(0, size.height * 0.45)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => false;
}

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kToolbarHeight,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.85),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.onSurface),
            onPressed: onClose,
          ),
          const Expanded(
            child: Text(
              'AR Navigation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
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

class _DirectionCard extends StatelessWidget {
  const _DirectionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_upward, size: 26, color: AppColors.onPrimary),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Walk straight 200m',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'towards Muzium Negara MRT',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FloatingActionBtn(icon: Icons.volume_up_outlined),
        const SizedBox(height: 10),
        _FloatingActionBtn(
          icon: Icons.my_location_outlined,
          color: AppColors.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _FloatingActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _FloatingActionBtn({
    required this.icon,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final VoidCallback onProgressTap;
  const _BottomPanel({required this.onProgressTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.88),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '150m',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'remaining',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '2 mins',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'Estimated arrival',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onProgressTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: LinearProgressIndicator(
                    value: 0.25,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceVariant,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
