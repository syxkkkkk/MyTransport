import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/transit_service.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final _mapController = MapController();
  final _transitService = TransitService();

  // Default center: KL City Centre
  LatLng _center = const LatLng(3.1478, 101.6953);
  LatLng? _userLocation;

  List<NearbyStation> _stations = [];
  NearbyStation? _selectedStation;
  bool _loadingLocation = true;
  bool _loadingStations = false;
  String? _locationError;
  double? _locationAccuracy; // metres

  // Line filter
  final Set<String> _activeLines = {};

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
      _locationAccuracy = null;
    });

    try {
      // 1 — Check location service
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _locationError = 'Location services are disabled. Enable GPS in Settings.';
          _loadingLocation = false;
        });
        _fetchNearbyStations(_center);
        return;
      }

      // 2 — Check / request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = permission == LocationPermission.deniedForever
              ? 'Location permission permanently denied. Enable it in app Settings.'
              : 'Location permission denied.';
          _loadingLocation = false;
        });
        _fetchNearbyStations(_center);
        return;
      }

      // 3 — Show last-known position immediately while GPS warms up
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        final loc = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() {
          _userLocation = loc;
          _center = loc;
          _locationAccuracy = lastKnown.accuracy;
        });
        _mapController.move(loc, 14.5);
        _fetchNearbyStations(loc);
      }

      // 4 — Get fresh high-accuracy GPS fix (15 s timeout)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('GPS took too long. Showing last known position.'),
      );

      if (!mounted) return;
      final loc = LatLng(position.latitude, position.longitude);

      // Only refetch stations if we moved more than 50 m from the last-known fix
      final moved = lastKnown == null ||
          Geolocator.distanceBetween(
              lastKnown.latitude, lastKnown.longitude,
              position.latitude, position.longitude) > 50;

      setState(() {
        _userLocation = loc;
        _center = loc;
        _loadingLocation = false;
        _locationAccuracy = position.accuracy;
        _locationError = null;
      });
      _mapController.move(loc, 14.5);
      if (moved) _fetchNearbyStations(loc);

    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
          // Only show error if we have no position at all
          if (_userLocation == null) {
            _locationError = e.message ?? 'GPS timeout. Move outdoors and try again.';
          }
        });
        if (_userLocation == null) _fetchNearbyStations(_center);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
          if (_userLocation == null) {
            _locationError = 'Could not get location. Try again outdoors.';
          }
        });
        if (_userLocation == null) _fetchNearbyStations(_center);
      }
    }
  }

  Future<void> _fetchNearbyStations(LatLng loc) async {
    setState(() => _loadingStations = true);
    try {
      final stations = await _transitService.getNearbyStations(
        loc.latitude,
        loc.longitude,
        radiusKm: 3,
      );
      if (mounted) {
        setState(() {
          _stations = stations;
          _loadingStations = false;
          if (stations.isNotEmpty && _selectedStation == null) {
            _selectedStation = stations.first;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStations = false);
    }
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  List<NearbyStation> get _filteredStations {
    if (_activeLines.isEmpty) return _stations;
    return _stations.where((s) => s.lines.any((l) => _activeLines.contains(l.line.code))).toList();
  }

  Set<String> get _allLineCodes {
    final codes = <String>{};
    for (final s in _stations) {
      for (final l in s.lines) {
        codes.add(l.line.code);
      }
    }
    return codes;
  }

  Map<String, String> get _lineColors {
    final map = <String, String>{};
    for (final s in _stations) {
      for (final l in s.lines) {
        map[l.line.code] = l.line.color;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 14.0,
              onTap: (_, __) => setState(() => _selectedStation = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mytransport.app',
              ),
              // Station markers
              MarkerLayer(
                markers: [
                  // User location blue dot
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 28,
                      height: 28,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Accuracy ring
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
                            ),
                          ),
                          // Blue dot
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Station markers
                  ..._filteredStations.map((station) {
                    final color = _parseColor(station.primaryColor);
                    final isSelected = _selectedStation?.id == station.id;
                    return Marker(
                      point: LatLng(station.latitude, station.longitude),
                      width: isSelected ? 44 : 36,
                      height: isSelected ? 54 : 44,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedStation = station),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: isSelected ? 40 : 32,
                              height: isSelected ? 40 : 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, offset: const Offset(0, 2))],
                              ),
                              child: const Icon(Icons.train, color: Colors.white, size: 14),
                            ),
                            Container(
                              width: 2,
                              height: isSelected ? 10 : 8,
                              color: color,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(context),
          ),

          // Loading indicator
          if (_loadingLocation || _loadingStations)
            Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text(
                        _loadingLocation
                            ? 'Getting your location…'
                            : _locationAccuracy != null
                                ? 'Loading stations… (GPS ±${_locationAccuracy!.toStringAsFixed(0)}m)'
                                : 'Loading nearby stations…',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurface),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Error snack-style banner
          if (_locationError != null)
            Positioned(
              top: 110,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_locationError!, style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade900)),
                    ),
                  ],
                ),
              ),
            ),

          // My location FAB
          Positioned(
            right: 16,
            bottom: _selectedStation != null ? 230 : 180,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              onPressed: _initLocation,
              backgroundColor: AppColors.surface,
              child: const Icon(Icons.my_location, color: AppColors.primary, size: 20),
            ),
          ),

          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(context),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.map),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surface, AppColors.surface.withOpacity(0)],
        ),
      ),
      child: Column(
        children: [
          // Search row
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceVariant),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.onSurfaceVariant, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                ),
                const Icon(Icons.search, color: AppColors.onSurfaceVariant, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nearby transit stations',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
                  ),
                ),
                Text(
                  '${_filteredStations.length} found',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),

          // Line filter chips
          if (_allLineCodes.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _allLineCodes.map((code) {
                  final color = _parseColor(_lineColors[code] ?? '#6B7280');
                  final active = _activeLines.contains(code);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (active) {
                          _activeLines.remove(code);
                        } else {
                          _activeLines.add(code);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: active ? color : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: active ? color : AppColors.surfaceVariant),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
                        ),
                        child: Text(
                          code,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : AppColors.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, AppColors.surface.withOpacity(0.95), AppColors.surface],
          stops: const [0.0, 0.2, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Station cards horizontal scroll
          if (_filteredStations.isNotEmpty) ...[
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredStations.length,
                itemBuilder: (ctx, i) {
                  final s = _filteredStations[i];
                  final isSelected = _selectedStation?.id == s.id;
                  final color = _parseColor(s.primaryColor);
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedStation = s);
                      _mapController.move(LatLng(s.latitude, s.longitude), 15);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 160,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withOpacity(0.1) : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? color : AppColors.surfaceVariant, width: isSelected ? 2 : 1),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  s.lines.isNotEmpty ? s.lines.first.line.code : '—',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${s.distanceKm.toStringAsFixed(1)}km',
                                style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.name,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.code,
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Selected station detail + confirm button
          if (_selectedStation != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Detail row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: _parseColor(_selectedStation!.primaryColor).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.train, color: _parseColor(_selectedStation!.primaryColor), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedStation!.name,
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  ..._selectedStation!.lines.map((l) => Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _parseColor(l.line.color),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(l.line.code, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                                  )),
                                  Text(
                                    '${_selectedStation!.distanceKm.toStringAsFixed(2)} km away',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/route-details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Get Route from ${_selectedStation!.name}',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!_loadingStations && _stations.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No transit stations found within 3km.\nTry moving the map to a different area.',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
