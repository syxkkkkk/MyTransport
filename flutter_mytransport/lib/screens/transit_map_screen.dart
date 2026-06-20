import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/gtfs_rail_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

class TransitMapScreen extends StatefulWidget {
  const TransitMapScreen({super.key});

  @override
  State<TransitMapScreen> createState() => _TransitMapScreenState();
}

class _TransitMapScreenState extends State<TransitMapScreen> {
  final MapController _mapCtrl = MapController();

  RailNetwork? _network;
  bool _loading = true;
  String? _error;

  RailStation? _selected;
  bool _legendExpanded = true;

  // KL city centre
  static const _klCenter = LatLng(3.1478, 101.6953);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final net = await GtfsRailService.getNetwork();
      if (!mounted) return;
      setState(() {
        _network = net;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load transit map: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
            Text('Rail Transit Map',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Rapid KL Network',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _legendExpanded ? Icons.legend_toggle : Icons.list_alt,
              color: AppColors.primary,
            ),
            tooltip: 'Toggle legend',
            onPressed: () => setState(() => _legendExpanded = !_legendExpanded),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            tooltip: 'Reload',
            onPressed: () {
              GtfsRailService.clearCache();
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildMap(),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.map),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Downloading transit network…\n(first load only)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 48, color: AppColors.outline),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Map ────────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    final net = _network!;

    // Build polylines from rail lines
    final polylines = <Polyline>[];
    for (final line in net.lines) {
      if (line.path.length < 2) continue;
      polylines.add(Polyline(
        points: line.path,
        strokeWidth: 4.0,
        color: line.color,
      ));
    }

    // Build station markers
    final markers = <Marker>[];
    for (final station in net.stations) {
      final isSelected = _selected?.id == station.id;
      final isInterchange = station.isInterchange;
      final size = isSelected ? 18.0 : (isInterchange ? 14.0 : 10.0);

      // Pick primary color from first serving line
      final lineColor = station.lineIds.isNotEmpty
          ? _lineColor(net, station.lineIds.first)
          : AppColors.onSurfaceVariant;

      markers.add(Marker(
        point: station.latLng,
        width: size,
        height: size,
        child: GestureDetector(
          onTap: () {
            setState(() => _selected = isSelected ? null : station);
            if (!isSelected) {
              _mapCtrl.move(station.latLng, 15.0);
            }
          },
          child: _StationDot(
            color: lineColor,
            isInterchange: isInterchange,
            isSelected: isSelected,
          ),
        ),
      ));
    }

    return Stack(
      children: [
        // ── Map ─────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _klCenter,
            initialZoom: 11.5,
            onTap: (_, __) => setState(() => _selected = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mytransport.mytransport',
            ),
            PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
          ],
        ),

        // ── Legend ──────────────────────────────────────────────────────────
        if (_legendExpanded)
          Positioned(
            top: 10,
            right: 10,
            child: _LegendCard(network: net),
          ),

        // ── Station detail card ──────────────────────────────────────────────
        if (_selected != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _StationCard(
              station: _selected!,
              network: net,
              onClose: () => setState(() => _selected = null),
            ),
          ),
      ],
    );
  }

  Color _lineColor(RailNetwork net, String routeId) {
    try {
      return net.lines.firstWhere((l) => l.id == routeId).color;
    } catch (_) {
      return AppColors.primary;
    }
  }
}

// ── Station dot marker ─────────────────────────────────────────────────────────

class _StationDot extends StatelessWidget {
  final Color color;
  final bool isInterchange;
  final bool isSelected;
  const _StationDot(
      {required this.color,
      required this.isInterchange,
      required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? color
            : (isInterchange ? Colors.white : color),
        border: Border.all(
          color: isSelected ? Colors.white : color,
          width: isSelected ? 2.5 : (isInterchange ? 2.0 : 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSelected ? 0.4 : 0.2),
            blurRadius: isSelected ? 6 : 3,
          ),
        ],
      ),
    );
  }
}

// ── Legend card ─────────────────────────────────────────────────────────────────

class _LegendCard extends StatelessWidget {
  final RailNetwork network;
  const _LegendCard({required this.network});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Rail Lines',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          for (final line in network.lines)
            if (line.path.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 4,
                      decoration: BoxDecoration(
                        color: line.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        line.displayName,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.onSurface,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          const Divider(height: 10, color: AppColors.outlineVariant),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              const Text('Interchange',
                  style: TextStyle(
                      fontSize: 9, color: AppColors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Station detail card ─────────────────────────────────────────────────────────

class _StationCard extends StatelessWidget {
  final RailStation station;
  final RailNetwork network;
  final VoidCallback onClose;
  const _StationCard(
      {required this.station,
      required this.network,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    // Find serving lines
    final lines = station.lineIds
        .map((id) {
          try {
            return network.lines.firstWhere((l) => l.id == id);
          } catch (_) {
            return null;
          }
        })
        .whereType<RailLine>()
        .toList();

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: lines.isNotEmpty
                  ? lines.first.color.withValues(alpha: 0.12)
                  : AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.train,
              size: 24,
              color: lines.isNotEmpty ? lines.first.color : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  station.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                if (station.isInterchange)
                  const Text(
                    'Interchange Station',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                  ),
                const SizedBox(height: 6),
                // Line badges
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: lines
                      .map((l) => _LineBadge(line: l))
                      .toList(),
                ),
              ],
            ),
          ),

          // Close
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.outline,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _LineBadge extends StatelessWidget {
  final RailLine line;
  const _LineBadge({required this.line});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: line.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        line.displayName,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
