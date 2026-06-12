import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _logoUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBV-MBafhuN1xSdHHX6FFYGzEHrKnnCoDX87dVFvYVSP4YlFZDbZXZjoiebEHG3C7IIqthh0iuAORTnJtJCAU4oHDLpAGjExCaPewGOhXnHBuE4pr3MwdUnRRpG41N5EWdDOy6iBvgqvmftwDwJAK6x9FCpR4NdoDA18TcqqKrC4n2THF3crEnwhFLd05dV9_hhHrKfsUCUpKFYvr9XAfuPGyUWQ580ZDT3edhA84-CDPvHsesgie3YHVoV4wYCrHrqFewsEhLiZUA';

  String _locationName    = 'Getting location…';
  String _locationAddress = '';
  bool   _loadingLocation = true;

  StreamSubscription<Position>? _positionSub;
  double? _lastLat, _lastLng;

  @override
  void initState() {
    super.initState();
    _startLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _startLocation() async {
    // 1 — Check service
    if (!await Geolocator.isLocationServiceEnabled()) {
      _setLocationText('Location disabled', 'Enable GPS in Settings');
      return;
    }

    // 2 — Check / request permission
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _setLocationText(
        'Location unavailable',
        perm == LocationPermission.deniedForever
            ? 'Allow in app Settings'
            : 'Permission denied',
      );
      return;
    }

    // 3 — Quick last-known snap
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      await _reverseGeocode(last.latitude, last.longitude);
    }

    // 4 — Live position stream (updates as you move)
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30, // update every 30 m of movement
      ),
    ).listen((pos) async {
      // Skip if barely moved
      if (_lastLat != null &&
          Geolocator.distanceBetween(
                  _lastLat!, _lastLng!, pos.latitude, pos.longitude) <
              30) return;
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
      await _reverseGeocode(pos.latitude, pos.longitude);
    });
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty || !mounted) return;

      final p = marks.first;

      // Best display name: subLocality → locality → name → coordinates
      final name = [p.subLocality, p.locality, p.name]
              .firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null) ??
          '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

      // Address line: street, subLocality, locality, postalCode
      final parts = [
        p.street,
        if (p.subLocality != name) p.subLocality,
        p.locality,
        p.postalCode,
      ].where((s) => s != null && s.isNotEmpty).join(', ');

      _setLocationText(name, parts);
    } catch (_) {
      if (_locationName == 'Getting location…') {
        _setLocationText(
          '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
          'Tap to view on map',
        );
      }
    }
  }

  void _setLocationText(String name, String address) {
    if (!mounted) return;
    setState(() {
      _locationName    = name;
      _locationAddress = address;
      _loadingLocation = false;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.06),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: CachedNetworkImage(
          imageUrl: _logoUrl,
          height: 32,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) =>
              const Icon(Icons.directions_transit, color: AppColors.primary),
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
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          _LocationCard(
            name:    _locationName,
            address: _locationAddress,
            loading: _loadingLocation,
            onPinTap:     () => Navigator.pushNamed(context, '/location-selection'),
            onRefreshTap: _startLocation,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/chatbot'),
            child: const _AIInputField(),
          ),
          const SizedBox(height: 16),
          _ShortcutsGrid(
            onNearbyStationsTap: () =>
                Navigator.pushNamed(context, '/location-selection'),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.home),
    );
  }
}

// ── Location card ─────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final String name;
  final String address;
  final bool loading;
  final VoidCallback onPinTap;
  final VoidCallback onRefreshTap;

  const _LocationCard({
    required this.name,
    required this.address,
    required this.loading,
    required this.onPinTap,
    required this.onRefreshTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.my_location, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'CURRENT LOCATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.outline,
                ),
              ),
              const Spacer(),
              // Refresh button
              GestureDetector(
                onTap: onRefreshTap,
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 16, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Location name
          loading
              ? Container(
                  height: 22,
                  width: 180,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
          const SizedBox(height: 4),

          // Address
          loading
              ? Container(
                  height: 14,
                  width: 240,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : Text(
                  address,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.surfaceVariant),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPinTap,
              icon: const Icon(Icons.push_pin_outlined, size: 16),
              label: const Text('Pin Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI input ──────────────────────────────────────────────────────────────────

class _AIInputField extends StatelessWidget {
  const _AIInputField();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const _PulsingBotIcon(),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Ask AI: How to get to KLCC?',
              style: TextStyle(fontSize: 15, color: AppColors.outline),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic_none, size: 18, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _PulsingBotIcon extends StatefulWidget {
  const _PulsingBotIcon();

  @override
  State<_PulsingBotIcon> createState() => _PulsingBotIconState();
}

class _PulsingBotIconState extends State<_PulsingBotIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: const Icon(Icons.smart_toy_outlined, size: 22, color: AppColors.primary),
    );
  }
}

// ── Shortcuts grid ────────────────────────────────────────────────────────────

class _ShortcutsGrid extends StatelessWidget {
  final VoidCallback onNearbyStationsTap;
  const _ShortcutsGrid({required this.onNearbyStationsTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ShortcutItem(
        icon: Icons.train_outlined,
        label: 'Nearby\nStations',
        bgColor: AppColors.primaryContainer,
        iconColor: AppColors.primary,
        onTap: onNearbyStationsTap,
      ),
      _ShortcutItem(
        icon: Icons.directions_bus_outlined,
        label: 'Bus\nRoutes',
        bgColor: AppColors.secondaryFixed,
        iconColor: AppColors.secondary,
        onTap: () {},
      ),
      _ShortcutItem(
        icon: Icons.route_outlined,
        label: 'Train\nRoutes',
        bgColor: AppColors.tertiaryFixed,
        iconColor: AppColors.tertiary,
        onTap: () {},
      ),
      _ShortcutItem(
        icon: Icons.bookmark_outline,
        label: 'Saved\nLocations',
        bgColor: AppColors.surfaceVariant,
        iconColor: AppColors.onSurfaceVariant,
        onTap: () {},
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: items.map((item) => _ShortcutCard(item: item)).toList(),
    );
  }
}

class _ShortcutItem {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;
  const _ShortcutItem({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });
}

class _ShortcutCard extends StatelessWidget {
  final _ShortcutItem item;
  const _ShortcutCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 24, color: item.iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                color: AppColors.onSurface,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
