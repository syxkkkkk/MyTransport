import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum NavTab { home, map, announcement, arNav, history, profile }

class BottomNavBar extends StatelessWidget {
  final NavTab currentTab;

  const BottomNavBar({super.key, required this.currentTab});

  void _navigate(BuildContext context, NavTab tab) {
    if (tab == currentTab) return;
    switch (tab) {
      case NavTab.home:
        Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
      case NavTab.map:
        Navigator.pushNamed(context, '/location-selection');
      case NavTab.announcement:
        Navigator.pushNamed(context, '/live-train');
      case NavTab.arNav:
        Navigator.pushNamed(context, '/ar-navigation');
      case NavTab.history:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History coming soon'), duration: Duration(seconds: 1)),
        );
      case NavTab.profile:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile coming soon'), duration: Duration(seconds: 1)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_outlined, label: 'Home', isActive: currentTab == NavTab.home, onTap: () => _navigate(context, NavTab.home)),
              _NavItem(icon: Icons.map_outlined, label: 'Map', isActive: currentTab == NavTab.map, onTap: () => _navigate(context, NavTab.map)),
              _NavItem(icon: Icons.campaign_outlined, label: 'Announce', isActive: currentTab == NavTab.announcement, onTap: () => _navigate(context, NavTab.announcement)),
              _NavItem(icon: Icons.qr_code_scanner_outlined, label: 'AR Nav', isActive: currentTab == NavTab.arNav, onTap: () => _navigate(context, NavTab.arNav)),
              _NavItem(icon: Icons.history_outlined, label: 'History', isActive: currentTab == NavTab.history, onTap: () => _navigate(context, NavTab.history)),
              _NavItem(icon: Icons.person_outline, label: 'Profile', isActive: currentTab == NavTab.profile, onTap: () => _navigate(context, NavTab.profile)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 10 : 6,
          vertical: 4,
        ),
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
