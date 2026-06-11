import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

class RouteDetailsScreen extends StatelessWidget {
  const RouteDetailsScreen({super.key});

  static const String _mapUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAWxXK2-d_hYIwRcSIHPkl5czDaF8l0-S8kbzIxcv1WoASrG7mpUJBxzjkW1i2rBAC9S9MNeJGI1lQYZEHgmgRGk3xZz9YLt251Ano68HwufqVbQEoICUsiO8RgYrnT45sbzHMBO5ecr1eYLAETj2xwnlNwlnhRpDR3BNwtG5PukoInGMzFTqGBnOUIzL8fJQc30A5uO7IOo7B3fUfzen8lx6zZ-ltqv9GYWArGwLJUkUp8kR8k4BUoteakgTjRTquAbmhRI8QbpUY';

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'MyTransport Malaysia',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        children: [
          // Route map card
          _RouteMapCard(mapUrl: _mapUrl),
          const SizedBox(height: 16),

          // Journey details
          const _JourneyDetailsCard(),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.map),
    );
  }
}

class _RouteMapCard extends StatelessWidget {
  final String mapUrl;
  const _RouteMapCard({required this.mapUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map image
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: mapUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: AppColors.surfaceContainerHigh,
                child: const Center(
                  child: Icon(Icons.map_outlined, size: 60, color: AppColors.outline),
                ),
              ),
            ),
          ),

          // Destination info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DESTINATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pavilion KL',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '25 min',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'RM 2.40',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyDetailsCard extends StatelessWidget {
  const _JourneyDetailsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Journey Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          const _TimelineStep(
            icon: Icons.directions_walk,
            iconBg: AppColors.surfaceVariant,
            iconColor: AppColors.onSurfaceVariant,
            title: 'Walk to Muzium Negara MRT',
            subtitle: 'Head east toward Jalan Damansara',
            duration: '5 min',
            hasLine: true,
          ),
          const _TrainStep(),
          const _TimelineStep(
            icon: Icons.location_on_outlined,
            iconBg: AppColors.surfaceVariant,
            iconColor: AppColors.onSurfaceVariant,
            title: 'Arrive at Bukit Bintang Station',
            subtitle: 'Exit at Gate D (Pavilion)',
            duration: null,
            hasLine: true,
          ),
          const _TimelineStep(
            icon: Icons.flag_outlined,
            iconBg: AppColors.primaryContainer,
            iconColor: AppColors.onPrimaryContainer,
            title: 'Walk to Pavilion KL',
            subtitle: 'Destination will be on the left',
            duration: '3 min',
            hasLine: false,
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? duration;
  final bool hasLine;

  const _TimelineStep({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.hasLine,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                if (hasLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 8, bottom: hasLine ? 24 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      if (duration != null)
                        Text(
                          duration!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainStep extends StatelessWidget {
  const _TrainStep();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.mrtGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.train, size: 22, color: Colors.white),
                ),
                Expanded(
                  child: Container(width: 2, color: AppColors.outlineVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'MRT Kajang Line',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        '12 min',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toward Kwasa Damansara',
                    style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.radio_button_checked, size: 16, color: AppColors.outline),
                        SizedBox(width: 6),
                        Text(
                          '3 stops',
                          style: TextStyle(fontSize: 13, color: AppColors.onSurface),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
