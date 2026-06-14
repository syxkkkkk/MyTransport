import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/transit_service.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final Completer<GoogleMapController> _mapCompleter = Completer();

  // Default center: KL City Centre
  LatLng _center = const LatLng(3.1478, 101.6953);
  LatLng? _userLocation;

  final _transitService = TransitService();
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
          _locationError =
              'Location services are disabled. Enable GPS in Settings.';
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
        _moveCamera(loc, 14.5);
        _fetchNearbyStations(loc);
      }

      // 4 — Get fresh high-accuracy GPS fix (15 s timeout)
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
            'GPS took too long. Showing last known position.'),
      );

      if (!mounted) return;
      final loc = LatLng(position.latitude, position.longitude);

      // Only refetch stations if moved more than 50 m
      final moved = lastKnown == null ||
          Geolocator.distanceBetween(lastKnown.latitude, lastKnown.longitude,
                  position.latitude, position.longitude) >
              50;

      setState(() {
        _userLocation = loc;
        _center = loc;
        _loadingLocation = false;
        _locationAccuracy = position.accuracy;
        _locationError = null;
      });
      _moveCamera(loc, 14.5);
      if (moved) _fetchNearbyStations(loc);
    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
          if (_userLocation == null) {
            _locationError =
                e.message ?? 'GPS timeout. Move outdoors and try again.';
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

  Future<void> _moveCamera(LatLng target, double zoom) async {
    final controller = await _mapCompleter.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom),
      ),
    );
  }

  Future<void> _fetchNearbyStations(LatLng loc) async {
    setState(() => _loadingStations = true);
    try {
      final stations = await _transitService.getNearbyStations(
        loc.latitude,
        loc.longitude,
        radiusKm: 50,
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

  double _colorToHue(String hex) {
    final hsv = HSVColor.fromColor(_parseColor(hex));
    return hsv.hue;
  }

  List<NearbyStation> get _filteredStations {
    if (_activeLines.isEmpty) return _stations;
    return _stations
        .where((s) => s.lines.any((l) => _activeLines.contains(l.line.code)))
        .toList();
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

  Set<Marker> _buildMarkers() {
    return _filteredStations.map((station) {
      final isSelected = _selectedStation?.id == station.id;
      return Marker(
        markerId: MarkerId(station.id),
        position: LatLng(station.latitude, station.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _colorToHue(station.primaryColor),
        ),
        zIndexInt: isSelected ? 1 : 0,
        onTap: () {
          setState(() => _selectedStation = station);
          _moveCamera(LatLng(station.latitude, station.longitude), 15.5);
        },
        infoWindow: InfoWindow(
          title: station.name,
          snippet: station.code,
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 14.0,
            ),
            onMapCreated: (controller) {
              if (!_mapCompleter.isCompleted) {
                _mapCompleter.complete(controller);
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            markers: _buildMarkers(),
            mapType: MapType.normal,
            onTap: (_) => setState(() => _selectedStation = null),
          ),

          // ── Top bar ─────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(context),
          ),

          // ── Loading chip ────────────────────────────────────────────────
          if (_loadingLocation || _loadingStations)
            Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1), blurRadius: 8)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _loadingLocation
                            ? 'Getting your location…'
                            : _locationAccuracy != null
                                ? 'Loading stations… (GPS ±${_locationAccuracy!.toStringAsFixed(0)}m)'
                                : 'Loading nearby stations…',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.onSurface),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Error banner ────────────────────────────────────────────────
          if (_locationError != null)
            Positioned(
              top: 110,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationError!,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── My-location FAB ─────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: _selectedStation != null ? 230 : 180,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              onPressed: _initLocation,
              backgroundColor: AppColors.surface,
              child: const Icon(Icons.my_location,
                  color: AppColors.primary, size: 20),
            ),
          ),

          // ── Bottom panel ────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(context),
          ),
        ],
      ),
      bottomNavigationBar:
          const BottomNavBar(currentTab: NavTab.map),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

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
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.onSurfaceVariant, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                ),
                const Icon(Icons.search,
                    color: AppColors.onSurfaceVariant, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nearby transit stations',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.onSurfaceVariant),
                  ),
                ),
                Text(
                  '${_filteredStations.length} found',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
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
                  final color =
                      _parseColor(_lineColors[code] ?? '#6B7280');
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: active ? color : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: active
                                  ? color
                                  : AppColors.surfaceVariant),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 4)
                          ],
                        ),
                        child: Text(
                          code,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                active ? Colors.white : AppColors.onSurface,
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

  // ── Bottom panel ──────────────────────────────────────────────────────────

  Widget _buildBottomPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.surface.withOpacity(0.95),
            AppColors.surface
          ],
          stops: const [0.0, 0.2, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Station cards
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
                      _moveCamera(
                          LatLng(s.latitude, s.longitude), 15.5);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 160,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.1)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSelected
                                ? color
                                : AppColors.surfaceVariant,
                            width: isSelected ? 2 : 1),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 6)
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  s.lines.isNotEmpty
                                      ? s.lines.first.line.code
                                      : '—',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: color),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${s.distanceKm.toStringAsFixed(1)}km',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color:
                                        AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.name,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.code,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant),
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

          // Selected station detail + confirm
          if (_selectedStation != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _parseColor(
                                    _selectedStation!.primaryColor)
                                .withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.train,
                            color: _parseColor(
                                _selectedStation!.primaryColor),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedStation!.name,
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  ..._selectedStation!.lines.map(
                                    (l) => Container(
                                      margin: const EdgeInsets.only(
                                          right: 4),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _parseColor(
                                            l.line.color),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        l.line.code,
                                        style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight:
                                                FontWeight.w800,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_selectedStation!.distanceKm.toStringAsFixed(2)} km away',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors
                                            .onSurfaceVariant),
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
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(
                          context, '/route-details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Get Route from ${_selectedStation!.name}',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
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
                    const Icon(Icons.info_outline,
                        color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No transit stations found within 3km.\nTry moving the map to a different area.',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant),
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
