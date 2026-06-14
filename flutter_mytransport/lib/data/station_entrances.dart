import 'package:flutter/material.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class StationEntrance {
  final String label;     // e.g. "Platform 1"
  final String direction; // e.g. "towards Gombak"
  final String lineCode;  // e.g. "LRT-KJ"
  final Color pinColor;
  final double lat;
  final double lng;

  const StationEntrance({
    required this.label,
    required this.direction,
    required this.lineCode,
    required this.pinColor,
    required this.lat,
    required this.lng,
  });

  /// Full display label shown on AR pin.
  String get fullLabel => '$label – $direction';
}

class StationEntranceData {
  final String stationId;
  final String stationName;
  final List<StationEntrance> entrances;

  const StationEntranceData({
    required this.stationId,
    required this.stationName,
    required this.entrances,
  });
}

// ── Database ──────────────────────────────────────────────────────────────────
// TODO: Replace placeholder coordinates with real field-collected GPS values.
// To collect: stand at each entrance/platform gate, open Google Maps,
// drop a pin, copy the lat/lng here.

const List<StationEntranceData> kStationEntrances = [

  // ── KL Sentral ─────────────────────────────────────────────────────────────
  StationEntranceData(
    stationId: 'ktm-kl-sentral',
    stationName: 'KL Sentral',
    entrances: [
      StationEntrance(
        label: 'Platform 1 & 2',
        direction: 'KTM Port Klang Line',
        lineCode: 'KTM-PK',
        pinColor: Color(0xFF00843D),
        lat: 3.1338, lng: 101.6855, // TODO: verify
      ),
      StationEntrance(
        label: 'Platform 3 & 4',
        direction: 'KTM Seremban Line',
        lineCode: 'KTM-SB',
        pinColor: Color(0xFFCC0000),
        lat: 3.1340, lng: 101.6870, // TODO: verify
      ),
      StationEntrance(
        label: 'LRT Entrance',
        direction: 'LRT Kelana Jaya Line',
        lineCode: 'LRT-KJ',
        pinColor: Color(0xFFE32026),
        lat: 3.1343, lng: 101.6864, // TODO: verify
      ),
      StationEntrance(
        label: 'ERL Gate',
        direction: 'KLIA Ekspres / KLIA Transit',
        lineCode: 'ERL',
        pinColor: Color(0xFF1B3F8A),
        lat: 3.1330, lng: 101.6862, // TODO: verify
      ),
      StationEntrance(
        label: 'Monorail Entrance',
        direction: 'KL Monorail',
        lineCode: 'MONO',
        pinColor: Color(0xFFE60000),
        lat: 3.1335, lng: 101.6868, // TODO: verify
      ),
    ],
  ),

  // ── Masjid Jamek ───────────────────────────────────────────────────────────
  StationEntranceData(
    stationId: 'lrt-masjid-jamek',
    stationName: 'Masjid Jamek',
    entrances: [
      StationEntrance(
        label: 'Platform 1',
        direction: 'LRT KJ Line → Gombak',
        lineCode: 'LRT-KJ',
        pinColor: Color(0xFFE32026),
        lat: 3.1497, lng: 101.6988, // TODO: verify
      ),
      StationEntrance(
        label: 'Platform 2',
        direction: 'LRT KJ Line → Kelana Jaya',
        lineCode: 'LRT-KJ',
        pinColor: Color(0xFFE32026),
        lat: 3.1489, lng: 101.6993, // TODO: verify
      ),
      StationEntrance(
        label: 'Platform 3',
        direction: 'LRT Ampang Line → Sentul Timur',
        lineCode: 'LRT-AMP',
        pinColor: Color(0xFF8B008B),
        lat: 3.1495, lng: 101.6996, // TODO: verify
      ),
      StationEntrance(
        label: 'Platform 4',
        direction: 'LRT Ampang Line → Ampang / Sri Petaling',
        lineCode: 'LRT-AMP',
        pinColor: Color(0xFF8B008B),
        lat: 3.1491, lng: 101.6999, // TODO: verify
      ),
    ],
  ),

  // ── KLCC ───────────────────────────────────────────────────────────────────
  StationEntranceData(
    stationId: 'lrt-klcc',
    stationName: 'KLCC',
    entrances: [
      StationEntrance(
        label: 'Platform 1',
        direction: 'LRT KJ Line → Gombak',
        lineCode: 'LRT-KJ',
        pinColor: Color(0xFFE32026),
        lat: 3.1588, lng: 101.7135, // TODO: verify
      ),
      StationEntrance(
        label: 'Platform 2',
        direction: 'LRT KJ Line → Kelana Jaya',
        lineCode: 'LRT-KJ',
        pinColor: Color(0xFFE32026),
        lat: 3.1578, lng: 101.7128, // TODO: verify
      ),
      StationEntrance(
        label: 'Entrance A',
        direction: 'Suria KLCC / Twin Towers',
        lineCode: 'LRT-KJ',
        pinColor: Color(0xFF4285F4),
        lat: 3.1580, lng: 101.7120, // TODO: verify
      ),
    ],
  ),

  // ── Bukit Bintang MRT ──────────────────────────────────────────────────────
  StationEntranceData(
    stationId: 'mrt-bukit-bintang',
    stationName: 'Bukit Bintang',
    entrances: [
      StationEntrance(
        label: 'Platform 1',
        direction: 'MRT Kajang Line → Sungai Buloh',
        lineCode: 'MRT-KJ',
        pinColor: Color(0xFF009A44),
        lat: 3.1465, lng: 101.7115, // TODO: verify
      ),
      StationEntrance(
        label: 'Platform 2',
        direction: 'MRT Kajang Line → Kajang',
        lineCode: 'MRT-KJ',
        pinColor: Color(0xFF009A44),
        lat: 3.1461, lng: 101.7108, // TODO: verify
      ),
      StationEntrance(
        label: 'Entrance A',
        direction: 'Pavilion KL / Jalan Bukit Bintang',
        lineCode: 'MRT-KJ',
        pinColor: Color(0xFF4285F4),
        lat: 3.1455, lng: 101.7113, // TODO: verify
      ),
    ],
  ),

  // ── Pasar Seni ─────────────────────────────────────────────────────────────
  StationEntranceData(
    stationId: 'lrt-pasar-seni',
    stationName: 'Pasar Seni',
    entrances: [
      StationEntrance(
        label: 'Platform 1',
        direction: 'LRT KJ Line → Gombak',
        lineCode: 'LRT-KJ',
        pinColor: Color(0xFFE32026),
        lat: 3.1445, lng: 101.6960, // TODO: verify
      ),
      StationEntrance(
        label: 'Platform 2',
        direction: 'LRT KJ Line → Kelana Jaya',
        lineCode: 'LRT-KJ',
        pinColor: Color(0xFFE32026),
        lat: 3.1441, lng: 101.6958, // TODO: verify
      ),
      StationEntrance(
        label: 'MRT Platform 1',
        direction: 'MRT Kajang Line → Sungai Buloh',
        lineCode: 'MRT-KJ',
        pinColor: Color(0xFF009A44),
        lat: 3.1438, lng: 101.6955, // TODO: verify
      ),
      StationEntrance(
        label: 'MRT Platform 2',
        direction: 'MRT Kajang Line → Kajang',
        lineCode: 'MRT-KJ',
        pinColor: Color(0xFF009A44),
        lat: 3.1435, lng: 101.6952, // TODO: verify
      ),
    ],
  ),

  // ── Titiwangsa ─────────────────────────────────────────────────────────────
  StationEntranceData(
    stationId: 'lrt-titiwangsa',
    stationName: 'Titiwangsa',
    entrances: [
      StationEntrance(
        label: 'Platform 1',
        direction: 'LRT Ampang Line → Sentul Timur',
        lineCode: 'LRT-AMP',
        pinColor: Color(0xFF8B008B),
        lat: 3.1805, lng: 101.7068, // TODO: verify
      ),
      StationEntrance(
        label: 'Platform 2',
        direction: 'LRT Ampang Line → Ampang / Sri Petaling',
        lineCode: 'LRT-AMP',
        pinColor: Color(0xFF8B008B),
        lat: 3.1800, lng: 101.7063, // TODO: verify
      ),
      StationEntrance(
        label: 'Monorail Platform',
        direction: 'KL Monorail → KL Sentral / Titiwangsa',
        lineCode: 'MONO',
        pinColor: Color(0xFFE60000),
        lat: 3.1798, lng: 101.7058, // TODO: verify
      ),
      StationEntrance(
        label: 'MRT Platform 1',
        direction: 'MRT Putrajaya Line → Kwasa Damansara',
        lineCode: 'MRT-PY',
        pinColor: Color(0xFF78BE20),
        lat: 3.1802, lng: 101.7060, // TODO: verify
      ),
    ],
  ),
];

/// Returns entrance data for a station, or null if not yet in the database.
StationEntranceData? getEntrancesForStation(String stationId) {
  try {
    return kStationEntrances.firstWhere((e) => e.stationId == stationId);
  } catch (_) {
    return null;
  }
}
