import 'dart:math';

// ── Models ────────────────────────────────────────────────────────────────────

class NearbyStation {
  final String id;
  final String code;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final List<StationLine> lines;

  NearbyStation({
    required this.id,
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.lines,
  });

  String get primaryColor {
    if (lines.isEmpty) return '#6B7280';
    return lines.first.line.color;
  }
}

class StationLine {
  final TransitLineInfo line;
  StationLine({required this.line});
}

class TransitLineInfo {
  final String code;
  final String name;
  final String color;
  TransitLineInfo({required this.code, required this.name, required this.color});
}

// ── Service ───────────────────────────────────────────────────────────────────

class TransitService {
  List<NearbyStation> getAllStations() {
    final list = _kStations.map((raw) {
      final lineData = raw['lines'] as List<Map<String, String>>;
      return NearbyStation(
        id: raw['id'] as String,
        code: raw['code'] as String,
        name: raw['name'] as String,
        latitude: raw['lat'] as double,
        longitude: raw['lng'] as double,
        distanceKm: 0,
        lines: lineData
            .map((l) => StationLine(
                  line: TransitLineInfo(
                    code: l['code']!,
                    name: l['name']!,
                    color: l['color']!,
                  ),
                ))
            .toList(),
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<List<NearbyStation>> getNearbyStations(
    double lat,
    double lon, {
    double radiusKm = 50,
  }) async {
    final results = <NearbyStation>[];

    for (final raw in _kStations) {
      final dist = _haversineKm(lat, lon, raw['lat'] as double, raw['lng'] as double);
      if (dist <= radiusKm) {
        final lineData = raw['lines'] as List<Map<String, String>>;
        results.add(NearbyStation(
          id: raw['id'] as String,
          code: raw['code'] as String,
          name: raw['name'] as String,
          latitude: raw['lat'] as double,
          longitude: raw['lng'] as double,
          distanceKm: double.parse(dist.toStringAsFixed(2)),
          lines: lineData
              .map((l) => StationLine(
                    line: TransitLineInfo(
                      code: l['code']!,
                      name: l['name']!,
                      color: l['color']!,
                    ),
                  ))
              .toList(),
        ));
      }
    }

    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return results;
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;

  // ── Route planning ──────────────────────────────────────────────────────────

  static RouteResult computeRoute(NearbyStation origin, NearbyStation destination) {
    if (origin.id == destination.id) {
      return RouteResult.sameStation(origin.name);
    }

    final originCodes = origin.lines.map((l) => l.line.code).toSet();
    final destCodes   = destination.lines.map((l) => l.line.code).toSet();

    // ── Direct (no transfer) ────────────────────────────────────────────────
    final shared = originCodes.intersection(destCodes);
    if (shared.isNotEmpty) {
      final code     = shared.first;
      final lineInfo = origin.lines.firstWhere((l) => l.line.code == code).line;
      final (stops, dirName) = _stopsAndDir(code, origin.id, destination.id);
      final mins     = (stops * 2.5).round() + 3;
      final fare     = _fare(code, stops);
      final detail   = _getStopsList(code, origin.id, destination.id);
      final platform = _platformLabel(code, origin.id, destination.id);
      return RouteResult(
        found: true,
        originName: origin.name,
        destName: destination.name,
        totalMinutes: mins,
        fareRM: fare,
        segments: [
          RouteSegment(type: SegmentType.ride, title: lineInfo.name,
            subtitle: 'Towards $dirName', lineCode: code,
            lineColor: lineInfo.color, stops: stops, minutes: mins - 3,
            stopsDetail: detail, boardingPlatform: platform),
          RouteSegment(type: SegmentType.arrive,
            title: 'Arrive at ${destination.name}', subtitle: 'Exit station'),
        ],
      );
    }

    // ── 1-transfer ──────────────────────────────────────────────────────────
    RouteResult? best;
    for (final raw in _kStations) {
      final stCodes = (raw['lines'] as List<Map<String, String>>)
          .map((l) => l['code']!)
          .toSet();
      final leg1Codes = originCodes.intersection(stCodes);
      final leg2Codes = destCodes.intersection(stCodes);
      if (leg1Codes.isEmpty || leg2Codes.isEmpty) continue;

      final xferId   = raw['id'] as String;
      final xferName = raw['name'] as String;
      final xferLines = (raw['lines'] as List<Map<String, String>>)
          .map((l) => StationLine(line: TransitLineInfo(
                code: l['code']!, name: l['name']!, color: l['color']!)))
          .toList();

      final c1 = leg1Codes.first;
      final c2 = leg2Codes.first;
      final l1 = origin.lines.firstWhere((l) => l.line.code == c1).line;
      final l2 = xferLines.firstWhere((l) => l.line.code == c2).line;

      final (s1, d1) = _stopsAndDir(c1, origin.id, xferId);
      final (s2, d2) = _stopsAndDir(c2, xferId, destination.id);
      final det1 = _getStopsList(c1, origin.id, xferId);
      final det2 = _getStopsList(c2, xferId, destination.id);
      final pl1  = _platformLabel(c1, origin.id, xferId);
      final pl2  = _platformLabel(c2, xferId, destination.id);

      final mins = (s1 * 2.5 + s2 * 2.5).round() + 8;
      final fare = _fare(c1, s1) + _fare(c2, s2);

      final candidate = RouteResult(
        found: true,
        originName: origin.name,
        destName: destination.name,
        totalMinutes: mins,
        fareRM: fare,
        segments: [
          RouteSegment(type: SegmentType.ride, title: l1.name,
            subtitle: 'Towards $d1', lineCode: c1,
            lineColor: l1.color, stops: s1, minutes: (s1 * 2.5).round(),
            stopsDetail: det1, boardingPlatform: pl1),
          RouteSegment(type: SegmentType.transfer,
            title: 'Transfer at $xferName',
            subtitle: 'Change to ${l2.name}',
            lineCode: c2, lineColor: l2.color, minutes: 5,
            transferStationId: xferId,
            boardingPlatform: pl2),
          RouteSegment(type: SegmentType.ride, title: l2.name,
            subtitle: 'Towards $d2', lineCode: c2,
            lineColor: l2.color, stops: s2, minutes: (s2 * 2.5).round(),
            stopsDetail: det2, boardingPlatform: pl2),
          RouteSegment(type: SegmentType.arrive,
            title: 'Arrive at ${destination.name}', subtitle: 'Exit station'),
        ],
      );

      if (best == null || candidate.totalMinutes < best.totalMinutes) {
        best = candidate;
      }
    }

    return best ?? RouteResult.notFound(origin.name, destination.name);
  }

  // Returns (stopCount, terminusName) for a segment on a line.
  static (int, String) _stopsAndDir(String code, String fromId, String toId) {
    final seq = _kLineSeqs[code];
    if (seq == null) return (8, _nameOf(toId));
    final iA = seq.indexOf(fromId);
    final iB = seq.indexOf(toId);
    if (iA < 0 || iB < 0) return (8, _nameOf(toId));
    final terminus = iB > iA ? seq.last : seq.first;
    return ((iB - iA).abs(), _nameOf(terminus));
  }

  /// All stations (including origin + destination) in travel order.
  static List<StationStop> _getStopsList(String code, String fromId, String toId) {
    final seq = _kLineSeqs[code];
    if (seq == null) return [];
    final iA = seq.indexOf(fromId);
    final iB = seq.indexOf(toId);
    if (iA < 0 || iB < 0) return [];
    final start = iA < iB ? iA : iB;
    final end   = iA < iB ? iB : iA;
    final ids   = seq.sublist(start, end + 1);
    final ordered = iA > iB ? ids.reversed.toList() : ids;
    return ordered.map((id) {
      try {
        final raw = _kStations.firstWhere((s) => s['id'] == id);
        return StationStop(id: id, name: raw['name'] as String,
            lat: raw['lat'] as double, lng: raw['lng'] as double);
      } catch (_) { return null; }
    }).whereType<StationStop>().toList();
  }

  /// Platform label based on travel direction in the sequence.
  static String _platformLabel(String code, String fromId, String toId) {
    final seq = _kLineSeqs[code];
    if (seq == null) return '';
    final iA = seq.indexOf(fromId);
    final iB = seq.indexOf(toId);
    if (iA < 0 || iB < 0) return '';
    final labels = _kPlatformLabels[code];
    if (labels == null) return '';
    return iB < iA ? labels['dec']! : labels['inc']!;
  }

  static String _nameOf(String id) {
    try {
      return _kStations.firstWhere((s) => s['id'] == id)['name'] as String;
    } catch (_) {
      return id;
    }
  }

  static double _fare(String code, int stops) {
    if (code == 'ERL') return 35.0;
    if (code.startsWith('KTM')) return (0.60 + stops * 0.25).clamp(0.60, 9.50);
    return (0.70 + stops * 0.12).clamp(0.70, 4.00);
  }
}

// ── Route models ──────────────────────────────────────────────────────────────

enum SegmentType { ride, transfer, arrive }

class StationStop {
  final String id;
  final String name;
  final double lat;
  final double lng;
  const StationStop({required this.id, required this.name,
      required this.lat, required this.lng});
}

class RouteSegment {
  final SegmentType type;
  final String title;
  final String subtitle;
  final String? lineCode;
  final String? lineColor;
  final int? stops;
  final int? minutes;
  /// All stops in order (including departure + arrival). Non-empty for ride segments.
  final List<StationStop> stopsDetail;
  /// e.g. "Platform 1 → Gombak"
  final String? boardingPlatform;
  /// Station ID of the transfer point (set on transfer segments).
  final String? transferStationId;

  const RouteSegment({
    required this.type,
    required this.title,
    required this.subtitle,
    this.lineCode,
    this.lineColor,
    this.stops,
    this.minutes,
    this.stopsDetail = const [],
    this.boardingPlatform,
    this.transferStationId,
  });
}

class RouteResult {
  final bool found;
  final bool isSameStation;
  final String originName;
  final String destName;
  final List<RouteSegment> segments;
  final int totalMinutes;
  final double fareRM;

  const RouteResult({
    required this.found,
    required this.originName,
    required this.destName,
    required this.segments,
    required this.totalMinutes,
    required this.fareRM,
    this.isSameStation = false,
  });

  factory RouteResult.notFound(String o, String d) =>
      RouteResult(found: false, originName: o, destName: d,
          segments: [], totalMinutes: 0, fareRM: 0);

  factory RouteResult.sameStation(String name) =>
      RouteResult(found: false, isSameStation: true,
          originName: name, destName: name,
          segments: [], totalMinutes: 0, fareRM: 0);
}

// ── Ordered station sequences per line ────────────────────────────────────────

const _lrtKJSeq = [
  'lrt-gombak','lrt-wangsa-maju','lrt-sri-rampai','lrt-setiawangsa',
  'lrt-jelatek','lrt-damai','lrt-ampang-park','lrt-klcc','lrt-dang-wangi',
  'lrt-masjid-jamek','lrt-pasar-seni','ktm-kl-sentral','lrt-bangsar',
  'lrt-universiti','lrt-kerinchi','lrt-abdullah-hukum','lrt-angkasapuri',
  'lrt-pantai-dalam','lrt-taman-jaya','lrt-asia-jaya','lrt-taman-paramount',
  'lrt-taman-bahagia','lrt-lembah-subang','lrt-ara-damansara',
  'lrt-subang-jaya-lrt','lrt-ss15','lrt-ss18','lrt-kelana-jaya',
];

const _lrtAMPSeq = [
  'lrt-sentul-timur','lrt-titiwangsa','lrt-pwtc','lrt-sultan-ismail',
  'lrt-bandaraya','lrt-masjid-jamek','lrt-hang-tuah','lrt-plaza-rakyat',
  'lrt-maluri','lrt-pandan-maju','lrt-pandan-jaya','lrt-pandan-indah',
  'ktm-bandar-tasik-selatan','lrt-tasik-selatan','lrt-sri-petaling',
  'lrt-bukit-jalil','lrt-batu-11-cheras','lrt-cempaka','lrt-cahaya','lrt-ampang',
];

const _mrtKJSeq = [
  'ktm-sungai-buloh','mrt-kwasa-damansara','mrt-kwasa-sentral',
  'mrt-kota-damansara','mrt-surian','mrt-mutiara-damansara','mrt-bandar-utama',
  'mrt-ttdi','mrt-phileo-damansara','mrt-pusat-bandar','mrt-semantan',
  'mrt-muzium-negara','mrt-merdeka','lrt-pasar-seni','mrt-bukit-bintang',
  'mrt-trx','mrt-cochrane','lrt-maluri','mrt-taman-pertama','mrt-taman-midah',
  'mrt-taman-mutiara','mrt-taman-connaught','mrt-taman-suntex',
  'mrt-batu-11-crs','mrt-kajang',
];

const _mrtPYSeq = [
  'mrt-kwasa-damansara','mrt-damansara-damai','mrt-sri-damansara-b',
  'mrt-sri-damansara-s','mrt-sri-damansara-t','mrt-metro-prima',
  'mrt-kepong-baru','mrt-jalan-ipoh-mrt','lrt-titiwangsa','mrt-hospital-kl',
  'lrt-ampang-park','mrt-conlay','mrt-trx','mrt-chan-sow-lin','mrt-kuchai',
  'mrt-seri-kembangan','mrt-cyberjaya-utara','mrt-cyberjaya-barat',
  'mrt-putrajaya-sentral','mrt-salak-tinggi',
];

const _ktmPKSeq = [
  'ktm-pelabuhan-klang','ktm-kampung-raja-uda','ktm-teluk-gadung',
  'ktm-teluk-pulai','ktm-klang','ktm-padang-jawa','ktm-batu-tiga',
  'ktm-shah-alam','ktm-subang-jaya','ktm-setia-jaya','ktm-seri-setia',
  'ktm-petaling','ktm-kl-sentral','ktm-kuala-lumpur','ktm-bank-negara',
  'ktm-putra','ktm-segambut','ktm-kepong','ktm-kepong-sentral',
  'ktm-sungai-buloh',
];

const _ktmSBSeq = [
  'ktm-batu-caves','ktm-kampung-batu','ktm-taman-wahyu','ktm-jalan-ipoh',
  'ktm-sentul','ktm-segambut','ktm-putra','ktm-bank-negara','ktm-kuala-lumpur',
  'ktm-kl-sentral','ktm-mid-valley','ktm-seputeh','ktm-salak-selatan',
  'ktm-bandar-tasik-selatan','ktm-serdang','ktm-ukm','ktm-bangi',
  'ktm-nilai','ktm-seremban','mrt-kajang',
];

const _monoSeq = [
  'ktm-kl-sentral','mono-tun-sambanthan','mono-maharajalela','lrt-hang-tuah',
  'mono-imbi','mono-bukit-bintang-m','mono-raja-chulan','mono-bukit-nanas',
  'lrt-dang-wangi','mono-chow-kit','lrt-titiwangsa',
];

const _erlSeq = [
  'ktm-kl-sentral','mrt-putrajaya-sentral','mrt-salak-tinggi',
  'erl-klia2','erl-klia',
];

// Platform labels: 'dec' = travelling toward lower index (seq[0] terminus)
//                  'inc' = travelling toward higher index (seq[last] terminus)
const _kPlatformLabels = <String, Map<String, String>>{
  'LRT-KJ':  {'dec': 'Platform 1 → Gombak',          'inc': 'Platform 2 → Kelana Jaya'},
  'LRT-AMP': {'dec': 'Platform 1 → Sentul Timur',     'inc': 'Platform 2 → Ampang / Sri Petaling'},
  'MRT-KJ':  {'dec': 'Platform 1 → Sungai Buloh',     'inc': 'Platform 2 → Kajang'},
  'MRT-PY':  {'dec': 'Platform 1 → Kwasa Damansara',  'inc': 'Platform 2 → Putrajaya'},
  'KTM-PK':  {'dec': 'Platform 1 → Port Klang',       'inc': 'Platform 2 → Sungai Buloh'},
  'KTM-SB':  {'dec': 'Platform 1 → Batu Caves',       'inc': 'Platform 2 → Seremban / Kajang'},
  'MONO':    {'dec': 'Platform 1 → KL Sentral',       'inc': 'Platform 2 → Titiwangsa'},
  'ERL':     {'dec': '',                               'inc': 'KLIA Ekspres / KLIA Transit'},
};

const _kLineSeqs = <String, List<String>>{
  'LRT-KJ':  _lrtKJSeq,
  'LRT-AMP': _lrtAMPSeq,
  'MRT-KJ':  _mrtKJSeq,
  'MRT-PY':  _mrtPYSeq,
  'KTM-PK':  _ktmPKSeq,
  'KTM-SB':  _ktmSBSeq,
  'MONO':    _monoSeq,
  'ERL':     _erlSeq,
};

// ── Station database ──────────────────────────────────────────────────────────
// Lines: KTM Port Klang, KTM Seremban, LRT Kelana Jaya, LRT Ampang/Sri Petaling,
//        MRT Kajang, MRT Putrajaya, KL Monorail, BRT Sunway, ERL

const _ktmPK  = {'code': 'KTM-PK',   'name': 'KTM Port Klang Line',      'color': '#00843D'};
const _ktmSB  = {'code': 'KTM-SB',   'name': 'KTM Seremban Line',        'color': '#CC0000'};
const _lrtKJ  = {'code': 'LRT-KJ',   'name': 'LRT Kelana Jaya Line',     'color': '#E32026'};
const _lrtAMP = {'code': 'LRT-AMP',  'name': 'LRT Ampang/Sri Petaling',  'color': '#8B008B'};
const _mrtKJ  = {'code': 'MRT-KJ',   'name': 'MRT Kajang Line',          'color': '#009A44'};
const _mrtPY  = {'code': 'MRT-PY',   'name': 'MRT Putrajaya Line',       'color': '#78BE20'};
const _mono   = {'code': 'MONO',     'name': 'KL Monorail',              'color': '#E60000'};
const _brt    = {'code': 'BRT-SW',   'name': 'BRT Sunway Line',          'color': '#FF6600'};
const _erl    = {'code': 'ERL',      'name': 'ERL KLIA Ekspres/Transit', 'color': '#1B3F8A'};

const List<Map<String, dynamic>> _kStations = [
  // ── KTM Port Klang Line ──────────────────────────────────────────────────
  {'id': 'ktm-pelabuhan-klang', 'code': 'PKL', 'name': 'Pelabuhan Klang',      'lat': 2.9997, 'lng': 101.3713, 'lines': [_ktmPK]},
  {'id': 'ktm-kampung-raja-uda','code': 'KRU', 'name': 'Kampung Raja Uda',     'lat': 3.0163, 'lng': 101.3850, 'lines': [_ktmPK]},
  {'id': 'ktm-teluk-gadung',    'code': 'TKG', 'name': 'Teluk Gadung',         'lat': 3.0210, 'lng': 101.4020, 'lines': [_ktmPK]},
  {'id': 'ktm-teluk-pulai',     'code': 'TKP', 'name': 'Teluk Pulai',          'lat': 3.0300, 'lng': 101.4220, 'lines': [_ktmPK]},
  {'id': 'ktm-klang',           'code': 'KLG', 'name': 'Klang',                'lat': 3.0449, 'lng': 101.4469, 'lines': [_ktmPK]},
  {'id': 'ktm-padang-jawa',     'code': 'PDJ', 'name': 'Padang Jawa',          'lat': 3.0720, 'lng': 101.5070, 'lines': [_ktmPK]},
  {'id': 'ktm-batu-tiga',       'code': 'BTG', 'name': 'Batu Tiga',            'lat': 3.0740, 'lng': 101.5038, 'lines': [_ktmPK]},
  {'id': 'ktm-shah-alam',       'code': 'SHA', 'name': 'Shah Alam',            'lat': 3.0794, 'lng': 101.5335, 'lines': [_ktmPK]},
  {'id': 'ktm-subang-jaya',     'code': 'SBJ', 'name': 'Subang Jaya',          'lat': 3.0623, 'lng': 101.5825, 'lines': [_ktmPK]},
  {'id': 'ktm-setia-jaya',      'code': 'STJ', 'name': 'Setia Jaya',           'lat': 3.0710, 'lng': 101.6028, 'lines': [_ktmPK]},
  {'id': 'ktm-seri-setia',      'code': 'SRS', 'name': 'Seri Setia',           'lat': 3.0727, 'lng': 101.6271, 'lines': [_ktmPK]},
  {'id': 'ktm-petaling',        'code': 'PTL', 'name': 'Petaling',             'lat': 3.0897, 'lng': 101.6624, 'lines': [_ktmPK]},
  {'id': 'ktm-kuala-lumpur',    'code': 'KLU', 'name': 'Kuala Lumpur',         'lat': 3.1414, 'lng': 101.6983, 'lines': [_ktmPK, _ktmSB]},
  {'id': 'ktm-kl-sentral',      'code': 'KLS', 'name': 'KL Sentral',           'lat': 3.1343, 'lng': 101.6864, 'lines': [_ktmPK, _ktmSB, _lrtKJ, _mono, _erl]},
  {'id': 'ktm-bank-negara',     'code': 'BNK', 'name': 'Bank Negara',          'lat': 3.1521, 'lng': 101.6960, 'lines': [_ktmPK, _ktmSB]},
  {'id': 'ktm-putra',           'code': 'PUT', 'name': 'Putra',                'lat': 3.1618, 'lng': 101.7016, 'lines': [_ktmPK, _ktmSB]},
  {'id': 'ktm-segambut',        'code': 'SGB', 'name': 'Segambut',             'lat': 3.1802, 'lng': 101.6883, 'lines': [_ktmPK, _ktmSB]},
  {'id': 'ktm-kepong-sentral',  'code': 'KPS', 'name': 'Kepong Sentral',       'lat': 3.2097, 'lng': 101.6343, 'lines': [_ktmPK]},
  {'id': 'ktm-kepong',          'code': 'KPN', 'name': 'Kepong',               'lat': 3.2017, 'lng': 101.6392, 'lines': [_ktmPK]},
  {'id': 'ktm-sungai-buloh',    'code': 'SGB2','name': 'Sungai Buloh',         'lat': 3.2100, 'lng': 101.5747, 'lines': [_ktmPK, _mrtKJ]},

  // ── KTM Seremban Line ───────────────────────────────────────────────────
  {'id': 'ktm-batu-caves',      'code': 'BTC', 'name': 'Batu Caves',           'lat': 3.2382, 'lng': 101.6838, 'lines': [_ktmSB]},
  {'id': 'ktm-kampung-batu',    'code': 'KGB', 'name': 'Kampung Batu',         'lat': 3.2253, 'lng': 101.6894, 'lines': [_ktmSB]},
  {'id': 'ktm-taman-wahyu',     'code': 'TWY', 'name': 'Taman Wahyu',          'lat': 3.2126, 'lng': 101.6954, 'lines': [_ktmSB]},
  {'id': 'ktm-jalan-ipoh',      'code': 'JIP', 'name': 'Jalan Ipoh',           'lat': 3.1939, 'lng': 101.6907, 'lines': [_ktmSB]},
  {'id': 'ktm-sentul',          'code': 'SNT', 'name': 'Sentul',               'lat': 3.1826, 'lng': 101.6938, 'lines': [_ktmSB]},
  {'id': 'ktm-mid-valley',      'code': 'MDV', 'name': 'Mid Valley',           'lat': 3.1174, 'lng': 101.6770, 'lines': [_ktmSB]},
  {'id': 'ktm-seputeh',         'code': 'SPT', 'name': 'Seputeh',              'lat': 3.0975, 'lng': 101.6878, 'lines': [_ktmSB]},
  {'id': 'ktm-salak-selatan',   'code': 'SSL', 'name': 'Salak Selatan',        'lat': 3.0822, 'lng': 101.7057, 'lines': [_ktmSB]},
  {'id': 'ktm-bandar-tasik-selatan','code':'BTS','name':'Bandar Tasik Selatan', 'lat': 3.0744, 'lng': 101.7063, 'lines': [_ktmSB, _lrtAMP]},
  {'id': 'ktm-serdang',         'code': 'SRD', 'name': 'Serdang',             'lat': 3.0289, 'lng': 101.7217, 'lines': [_ktmSB]},
  {'id': 'ktm-ukm',             'code': 'UKM', 'name': 'UKM',                 'lat': 3.0102, 'lng': 101.7228, 'lines': [_ktmSB]},
  {'id': 'ktm-bangi',           'code': 'BNG', 'name': 'Bangi',               'lat': 2.9706, 'lng': 101.7563, 'lines': [_ktmSB]},
  {'id': 'ktm-nilai',           'code': 'NLI', 'name': 'Nilai',               'lat': 2.8212, 'lng': 101.7939, 'lines': [_ktmSB]},
  {'id': 'ktm-seremban',        'code': 'SBN', 'name': 'Seremban',            'lat': 2.7274, 'lng': 101.9388, 'lines': [_ktmSB]},

  // ── LRT Kelana Jaya Line ─────────────────────────────────────────────────
  {'id': 'lrt-gombak',          'code': 'GMB', 'name': 'Gombak',              'lat': 3.2184, 'lng': 101.7347, 'lines': [_lrtKJ]},
  {'id': 'lrt-wangsa-maju',     'code': 'WMJ', 'name': 'Wangsa Maju',        'lat': 3.2027, 'lng': 101.7286, 'lines': [_lrtKJ]},
  {'id': 'lrt-sri-rampai',      'code': 'SRP', 'name': 'Sri Rampai',         'lat': 3.1928, 'lng': 101.7222, 'lines': [_lrtKJ]},
  {'id': 'lrt-setiawangsa',     'code': 'STW', 'name': 'Setiawangsa',        'lat': 3.1793, 'lng': 101.7175, 'lines': [_lrtKJ]},
  {'id': 'lrt-jelatek',         'code': 'JLT', 'name': 'Jelatek',            'lat': 3.1724, 'lng': 101.7223, 'lines': [_lrtKJ]},
  {'id': 'lrt-damai',           'code': 'DAM', 'name': 'Damai',              'lat': 3.1657, 'lng': 101.7272, 'lines': [_lrtKJ]},
  {'id': 'lrt-ampang-park',     'code': 'AMP', 'name': 'Ampang Park',        'lat': 3.1594, 'lng': 101.7210, 'lines': [_lrtKJ, _mrtPY]},
  {'id': 'lrt-klcc',            'code': 'KLC', 'name': 'KLCC',               'lat': 3.1579, 'lng': 101.7133, 'lines': [_lrtKJ]},
  {'id': 'lrt-dang-wangi',      'code': 'DWG', 'name': 'Dang Wangi',         'lat': 3.1571, 'lng': 101.7037, 'lines': [_lrtKJ, _mono]},
  {'id': 'lrt-masjid-jamek',    'code': 'MJK', 'name': 'Masjid Jamek',       'lat': 3.1493, 'lng': 101.6997, 'lines': [_lrtKJ, _lrtAMP]},
  {'id': 'lrt-pasar-seni',      'code': 'PSN', 'name': 'Pasar Seni',         'lat': 3.1441, 'lng': 101.6958, 'lines': [_lrtKJ, _mrtKJ]},
  {'id': 'lrt-bangsar',         'code': 'BGS', 'name': 'Bangsar',            'lat': 3.1248, 'lng': 101.6764, 'lines': [_lrtKJ]},
  {'id': 'lrt-universiti',      'code': 'UNI', 'name': 'Universiti',         'lat': 3.1178, 'lng': 101.6637, 'lines': [_lrtKJ]},
  {'id': 'lrt-kerinchi',        'code': 'KRC', 'name': 'Kerinchi',           'lat': 3.1129, 'lng': 101.6551, 'lines': [_lrtKJ]},
  {'id': 'lrt-abdullah-hukum',  'code': 'ABH', 'name': 'Abdullah Hukum',    'lat': 3.1108, 'lng': 101.6492, 'lines': [_lrtKJ]},
  {'id': 'lrt-angkasapuri',     'code': 'AKS', 'name': 'Angkasapuri',       'lat': 3.1068, 'lng': 101.6452, 'lines': [_lrtKJ]},
  {'id': 'lrt-pantai-dalam',    'code': 'PTD', 'name': 'Pantai Dalam',       'lat': 3.1009, 'lng': 101.6508, 'lines': [_lrtKJ]},
  {'id': 'lrt-taman-jaya',      'code': 'TMJ', 'name': 'Taman Jaya',         'lat': 3.0990, 'lng': 101.6410, 'lines': [_lrtKJ]},
  {'id': 'lrt-asia-jaya',       'code': 'ASJ', 'name': 'Asia Jaya',          'lat': 3.1070, 'lng': 101.6303, 'lines': [_lrtKJ]},
  {'id': 'lrt-taman-paramount', 'code': 'TMP', 'name': 'Taman Paramount',    'lat': 3.1094, 'lng': 101.6214, 'lines': [_lrtKJ]},
  {'id': 'lrt-taman-bahagia',   'code': 'TMB', 'name': 'Taman Bahagia',      'lat': 3.1111, 'lng': 101.6119, 'lines': [_lrtKJ]},
  {'id': 'lrt-lembah-subang',   'code': 'LBS', 'name': 'Lembah Subang',      'lat': 3.0913, 'lng': 101.6023, 'lines': [_lrtKJ]},
  {'id': 'lrt-ara-damansara',   'code': 'ARD', 'name': 'Ara Damansara',      'lat': 3.1159, 'lng': 101.5785, 'lines': [_lrtKJ]},
  {'id': 'lrt-subang-jaya-lrt', 'code': 'SJL', 'name': 'Subang Jaya (LRT)', 'lat': 3.0570, 'lng': 101.5840, 'lines': [_lrtKJ]},
  {'id': 'lrt-ss15',            'code': 'SS15','name': 'SS15',               'lat': 3.0738, 'lng': 101.5876, 'lines': [_lrtKJ]},
  {'id': 'lrt-ss18',            'code': 'SS18','name': 'SS18',               'lat': 3.0807, 'lng': 101.5831, 'lines': [_lrtKJ]},
  {'id': 'lrt-kelana-jaya',     'code': 'KLJ', 'name': 'Kelana Jaya',        'lat': 3.1062, 'lng': 101.5876, 'lines': [_lrtKJ]},

  // ── LRT Ampang / Sri Petaling Line ───────────────────────────────────────
  {'id': 'lrt-sentul-timur',    'code': 'STM', 'name': 'Sentul Timur',       'lat': 3.1846, 'lng': 101.7020, 'lines': [_lrtAMP]},
  {'id': 'lrt-titiwangsa',      'code': 'TTW', 'name': 'Titiwangsa',         'lat': 3.1800, 'lng': 101.7063, 'lines': [_lrtAMP, _mono, _mrtPY]},
  {'id': 'lrt-pwtc',            'code': 'PWT', 'name': 'PWTC',               'lat': 3.1668, 'lng': 101.7020, 'lines': [_lrtAMP]},
  {'id': 'lrt-sultan-ismail',   'code': 'SUI', 'name': 'Sultan Ismail',      'lat': 3.1614, 'lng': 101.7023, 'lines': [_lrtAMP]},
  {'id': 'lrt-bandaraya',       'code': 'BDY', 'name': 'Bandaraya',          'lat': 3.1553, 'lng': 101.7010, 'lines': [_lrtAMP]},
  {'id': 'lrt-hang-tuah',       'code': 'HGT', 'name': 'Hang Tuah',         'lat': 3.1416, 'lng': 101.7043, 'lines': [_lrtAMP, _mono]},
  {'id': 'lrt-plaza-rakyat',    'code': 'PLR', 'name': 'Plaza Rakyat',       'lat': 3.1413, 'lng': 101.7034, 'lines': [_lrtAMP]},
  {'id': 'lrt-maluri',          'code': 'MLR', 'name': 'Maluri',             'lat': 3.1232, 'lng': 101.7299, 'lines': [_lrtAMP, _mrtKJ]},
  {'id': 'lrt-pandan-indah',    'code': 'PDI', 'name': 'Pandan Indah',       'lat': 3.1134, 'lng': 101.7443, 'lines': [_lrtAMP]},
  {'id': 'lrt-pandan-jaya',     'code': 'PDJ2','name': 'Pandan Jaya',        'lat': 3.1079, 'lng': 101.7490, 'lines': [_lrtAMP]},
  {'id': 'lrt-pandan-maju',     'code': 'PDM', 'name': 'Pandan Maju',        'lat': 3.1009, 'lng': 101.7468, 'lines': [_lrtAMP]},
  {'id': 'lrt-miharja',         'code': 'MHJ', 'name': 'Miharja',            'lat': 3.0937, 'lng': 101.7367, 'lines': [_lrtAMP]},
  {'id': 'lrt-cheras',          'code': 'CHR', 'name': 'Cheras',             'lat': 3.0820, 'lng': 101.7355, 'lines': [_lrtAMP]},
  {'id': 'lrt-batu-11-cheras',  'code': 'B11', 'name': 'Batu 11 Cheras',    'lat': 3.0653, 'lng': 101.7398, 'lines': [_lrtAMP]},
  {'id': 'lrt-bukit-jalil',     'code': 'BJL', 'name': 'Bukit Jalil',        'lat': 3.0572, 'lng': 101.6934, 'lines': [_lrtAMP]},
  {'id': 'lrt-sri-petaling',    'code': 'SRP2','name': 'Sri Petaling',        'lat': 3.0688, 'lng': 101.7052, 'lines': [_lrtAMP]},
  {'id': 'lrt-tasik-selatan',   'code': 'TSS', 'name': 'Tasik Selatan',      'lat': 3.0726, 'lng': 101.7076, 'lines': [_lrtAMP]},
  {'id': 'lrt-ampang',          'code': 'APG', 'name': 'Ampang',             'lat': 3.1280, 'lng': 101.7649, 'lines': [_lrtAMP]},
  {'id': 'lrt-cahaya',          'code': 'CAH', 'name': 'Cahaya',             'lat': 3.1245, 'lng': 101.7573, 'lines': [_lrtAMP]},
  {'id': 'lrt-cempaka',         'code': 'CMP', 'name': 'Cempaka',            'lat': 3.1238, 'lng': 101.7505, 'lines': [_lrtAMP]},

  // ── MRT Kajang Line ───────────────────────────────────────────────────────
  {'id': 'mrt-kwasa-damansara',  'code': 'KWD', 'name': 'Kwasa Damansara',   'lat': 3.1745, 'lng': 101.5596, 'lines': [_mrtKJ, _mrtPY]},
  {'id': 'mrt-kwasa-sentral',    'code': 'KWS', 'name': 'Kwasa Sentral',     'lat': 3.1690, 'lng': 101.5676, 'lines': [_mrtKJ]},
  {'id': 'mrt-kota-damansara',   'code': 'KTD', 'name': 'Kota Damansara',    'lat': 3.1668, 'lng': 101.5776, 'lines': [_mrtKJ]},
  {'id': 'mrt-surian',           'code': 'SRN', 'name': 'Surian',            'lat': 3.1606, 'lng': 101.5934, 'lines': [_mrtKJ]},
  {'id': 'mrt-mutiara-damansara','code': 'MTD', 'name': 'Mutiara Damansara', 'lat': 3.1536, 'lng': 101.6077, 'lines': [_mrtKJ]},
  {'id': 'mrt-bandar-utama',     'code': 'BDU', 'name': 'Bandar Utama',      'lat': 3.1496, 'lng': 101.6182, 'lines': [_mrtKJ]},
  {'id': 'mrt-ttdi',             'code': 'TTD', 'name': 'TTDI',              'lat': 3.1427, 'lng': 101.6283, 'lines': [_mrtKJ]},
  {'id': 'mrt-phileo-damansara', 'code': 'PHD', 'name': 'Phileo Damansara',  'lat': 3.1360, 'lng': 101.6401, 'lines': [_mrtKJ]},
  {'id': 'mrt-pusat-bandar',     'code': 'PBD', 'name': 'Pusat Bandar Damansara','lat': 3.1330,'lng': 101.6498, 'lines': [_mrtKJ]},
  {'id': 'mrt-semantan',         'code': 'SMT', 'name': 'Semantan',          'lat': 3.1317, 'lng': 101.6618, 'lines': [_mrtKJ]},
  {'id': 'mrt-muzium-negara',    'code': 'MZN', 'name': 'Muzium Negara',     'lat': 3.1378, 'lng': 101.6820, 'lines': [_mrtKJ]},
  {'id': 'mrt-merdeka',          'code': 'MRD', 'name': 'Merdeka',           'lat': 3.1425, 'lng': 101.6926, 'lines': [_mrtKJ]},
  {'id': 'mrt-bukit-bintang',    'code': 'BBT', 'name': 'Bukit Bintang',     'lat': 3.1462, 'lng': 101.7108, 'lines': [_mrtKJ]},
  {'id': 'mrt-trx',              'code': 'TRX', 'name': 'Tun Razak Exchange','lat': 3.1429, 'lng': 101.7192, 'lines': [_mrtKJ, _mrtPY]},
  {'id': 'mrt-cochrane',         'code': 'CCR', 'name': 'Cochrane',          'lat': 3.1339, 'lng': 101.7248, 'lines': [_mrtKJ]},
  {'id': 'mrt-taman-pertama',    'code': 'TPT', 'name': 'Taman Pertama',     'lat': 3.1177, 'lng': 101.7414, 'lines': [_mrtKJ]},
  {'id': 'mrt-taman-midah',      'code': 'TMD', 'name': 'Taman Midah',       'lat': 3.1055, 'lng': 101.7454, 'lines': [_mrtKJ]},
  {'id': 'mrt-taman-mutiara',    'code': 'TMU', 'name': 'Taman Mutiara',     'lat': 3.0971, 'lng': 101.7468, 'lines': [_mrtKJ]},
  {'id': 'mrt-taman-connaught',  'code': 'TCN', 'name': 'Taman Connaught',   'lat': 3.0882, 'lng': 101.7456, 'lines': [_mrtKJ]},
  {'id': 'mrt-taman-suntex',     'code': 'TSX', 'name': 'Taman Suntex',      'lat': 3.0795, 'lng': 101.7456, 'lines': [_mrtKJ]},
  {'id': 'mrt-batu-11-crs',      'code': 'B11C','name': 'Batu 11 Cheras (MRT)','lat': 3.0654,'lng': 101.7430, 'lines': [_mrtKJ]},
  {'id': 'mrt-kajang',           'code': 'KJG', 'name': 'Kajang',            'lat': 2.9932, 'lng': 101.7875, 'lines': [_mrtKJ, _ktmSB]},

  // ── MRT Putrajaya Line ────────────────────────────────────────────────────
  {'id': 'mrt-damansara-damai',  'code': 'DDD', 'name': 'Damansara Damai',   'lat': 3.1844, 'lng': 101.5691, 'lines': [_mrtPY]},
  {'id': 'mrt-sri-damansara-b',  'code': 'SDB', 'name': 'Sri Damansara Barat','lat': 3.1874,'lng': 101.5820, 'lines': [_mrtPY]},
  {'id': 'mrt-sri-damansara-s',  'code': 'SDS', 'name': 'Sri Damansara Sentral','lat': 3.1939,'lng': 101.5973,'lines': [_mrtPY]},
  {'id': 'mrt-sri-damansara-t',  'code': 'SDT', 'name': 'Sri Damansara Timur','lat': 3.1993,'lng': 101.6114, 'lines': [_mrtPY]},
  {'id': 'mrt-metro-prima',      'code': 'MPR', 'name': 'Metro Prima',        'lat': 3.2017, 'lng': 101.6270, 'lines': [_mrtPY]},
  {'id': 'mrt-kepong-baru',      'code': 'KPB', 'name': 'Kepong Baru',        'lat': 3.2023, 'lng': 101.6437, 'lines': [_mrtPY]},
  {'id': 'mrt-jalan-ipoh-mrt',   'code': 'JIM', 'name': 'Jalan Ipoh (MRT)',   'lat': 3.1939, 'lng': 101.6849, 'lines': [_mrtPY]},
  {'id': 'mrt-titiwangsa-mrt',   'code': 'TTM', 'name': 'Titiwangsa (MRT)',   'lat': 3.1800, 'lng': 101.7063, 'lines': [_mrtPY]},
  {'id': 'mrt-hospital-kl',      'code': 'HKL', 'name': 'Hospital Kuala Lumpur','lat': 3.1679,'lng': 101.7069,'lines': [_mrtPY]},
  {'id': 'mrt-conlay',           'code': 'CNL', 'name': 'Conlay',             'lat': 3.1534, 'lng': 101.7154, 'lines': [_mrtPY]},
  {'id': 'mrt-chan-sow-lin',     'code': 'CSL', 'name': 'Chan Sow Lin',       'lat': 3.1197, 'lng': 101.7278, 'lines': [_mrtPY]},
  {'id': 'mrt-kuchai',           'code': 'KCH', 'name': 'Kuchai',             'lat': 3.0900, 'lng': 101.7090, 'lines': [_mrtPY]},
  {'id': 'mrt-seri-kembangan',   'code': 'SKB', 'name': 'Seri Kembangan',     'lat': 3.0217, 'lng': 101.7199, 'lines': [_mrtPY]},
  {'id': 'mrt-cyberjaya-utara',  'code': 'CJU', 'name': 'Cyberjaya Utara',    'lat': 2.9395, 'lng': 101.6538, 'lines': [_mrtPY]},
  {'id': 'mrt-cyberjaya-barat',  'code': 'CJB', 'name': 'Cyberjaya Barat',    'lat': 2.9197, 'lng': 101.6387, 'lines': [_mrtPY]},
  {'id': 'mrt-putrajaya-sentral','code': 'PJS', 'name': 'Putrajaya Sentral',  'lat': 2.9001, 'lng': 101.6741, 'lines': [_mrtPY, _erl]},
  {'id': 'mrt-salak-tinggi',     'code': 'SLT', 'name': 'Salak Tinggi',       'lat': 2.9512, 'lng': 101.7245, 'lines': [_mrtPY, _erl]},

  // ── KL Monorail ───────────────────────────────────────────────────────────
  {'id': 'mono-tun-sambanthan',  'code': 'TSB', 'name': 'Tun Sambanthan',     'lat': 3.1312, 'lng': 101.6867, 'lines': [_mono]},
  {'id': 'mono-maharajalela',    'code': 'MRL', 'name': 'Maharajalela',       'lat': 3.1370, 'lng': 101.6968, 'lines': [_mono]},
  {'id': 'mono-imbi',            'code': 'IMB', 'name': 'Imbi',               'lat': 3.1451, 'lng': 101.7113, 'lines': [_mono]},
  {'id': 'mono-bukit-bintang-m', 'code': 'BBM', 'name': 'Bukit Bintang (Mono)','lat': 3.1476,'lng': 101.7131, 'lines': [_mono]},
  {'id': 'mono-raja-chulan',     'code': 'RJC', 'name': 'Raja Chulan',        'lat': 3.1520, 'lng': 101.7116, 'lines': [_mono]},
  {'id': 'mono-bukit-nanas',     'code': 'BKN', 'name': 'Bukit Nanas',        'lat': 3.1570, 'lng': 101.7037, 'lines': [_mono]},
  {'id': 'mono-chow-kit',        'code': 'CWK', 'name': 'Chow Kit',           'lat': 3.1683, 'lng': 101.7003, 'lines': [_mono]},

  // ── BRT Sunway Line ───────────────────────────────────────────────────────
  {'id': 'brt-sunway',           'code': 'SWY', 'name': 'Sunway',             'lat': 3.0668, 'lng': 101.6039, 'lines': [_brt]},
  {'id': 'brt-sunway-lagoon',    'code': 'SWL', 'name': 'Sunway Lagoon',      'lat': 3.0726, 'lng': 101.6068, 'lines': [_brt]},
  {'id': 'brt-sunway-south-quay','code': 'SWQ', 'name': 'Sunway South Quay',  'lat': 3.0649, 'lng': 101.6106, 'lines': [_brt]},
  {'id': 'brt-sri-muda',         'code': 'SMD', 'name': 'Sri Muda',           'lat': 3.0770, 'lng': 101.5785, 'lines': [_brt]},

  // ── ERL ───────────────────────────────────────────────────────────────────
  {'id': 'erl-klia',             'code': 'KLIA','name': 'KLIA',               'lat': 2.7456, 'lng': 101.7099, 'lines': [_erl]},
  {'id': 'erl-klia2',            'code': 'KL2', 'name': 'klia2',              'lat': 2.7438, 'lng': 101.7020, 'lines': [_erl]},
];
