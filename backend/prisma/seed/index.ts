import { PrismaClient, LineType } from '@prisma/client';
import { logger } from '../../src/utils/logger';

const prisma = new PrismaClient();

// ─── Transit Lines ─────────────────────────────────────────────────────────────
const LINES = [
  { code: 'KJ', name: 'Kelana Jaya Line', shortName: 'KJ Line', color: '#E51937', type: LineType.LRT, operator: 'Rapid KL' },
  { code: 'KG', name: 'Kajang Line', shortName: 'Kajang Line', color: '#00A54F', type: LineType.LRT, operator: 'Rapid KL' },
  { code: 'MRT_PY', name: 'Putrajaya Line', shortName: 'PY Line', color: '#007B5F', type: LineType.MRT, operator: 'Prasarana' },
  { code: 'BRT', name: 'BRT Sunway', shortName: 'BRT Sunway', color: '#F7941D', type: LineType.BRT, operator: 'Rapid KL' },
  { code: 'KTM_KL', name: 'KTM Komuter (KL Sentral–Batu Caves)', shortName: 'KTM Komuter', color: '#6F2585', type: LineType.KTM, operator: 'KTM' },
  { code: 'ERL', name: 'KLIA Ekspres / KLIA Transit', shortName: 'ERL', color: '#CC0000', type: LineType.ERL, operator: 'KLIA Transit' },
  { code: 'MRL', name: 'KL Monorail', shortName: 'Monorail', color: '#F15A22', type: LineType.MONORAIL, operator: 'Rapid KL' },
];

// ─── KJ Line Stations ──────────────────────────────────────────────────────────
const KJ_STATIONS = [
  { code: 'KJ01', name: 'Putra Heights', nameMy: 'Putra Heights', lat: 3.0131, lon: 101.5615, seq: 1, zone: 6 },
  { code: 'KJ02', name: 'Alam Sutera', nameMy: 'Alam Sutera', lat: 3.0267, lon: 101.5785, seq: 2, zone: 6 },
  { code: 'KJ03', name: 'Kinrara BK5', nameMy: 'Kinrara BK5', lat: 3.0472, lon: 101.5896, seq: 3, zone: 5 },
  { code: 'KJ04', name: 'IOI Puchong Jaya', nameMy: 'IOI Puchong Jaya', lat: 3.0574, lon: 101.6031, seq: 4, zone: 5 },
  { code: 'KJ05', name: 'Puchong Prima', nameMy: 'Puchong Prima', lat: 3.0612, lon: 101.6179, seq: 5, zone: 5 },
  { code: 'KJ06', name: 'Puchong Perdana', nameMy: 'Puchong Perdana', lat: 3.0682, lon: 101.6281, seq: 6, zone: 4 },
  { code: 'KJ07', name: 'Pusat Bandar Puchong', nameMy: 'Pusat Bandar Puchong', lat: 3.0745, lon: 101.6394, seq: 7, zone: 4 },
  { code: 'KJ08', name: 'Taman Perindustrian Puchong', nameMy: 'Taman Perindustrian Puchong', lat: 3.0823, lon: 101.6531, seq: 8, zone: 4 },
  { code: 'KJ09', name: 'Glenmarie', nameMy: 'Glenmarie', lat: 3.1023, lon: 101.6721, seq: 9, zone: 3 },
  { code: 'KJ10', name: 'Subang Jaya', nameMy: 'Subang Jaya', lat: 3.0869, lon: 101.6521, seq: 10, zone: 4 },
  { code: 'KJ11', name: 'USJ 21', nameMy: 'USJ 21', lat: 3.0789, lon: 101.6412, seq: 11, zone: 4 },
  { code: 'KJ12', name: 'Taipan', nameMy: 'Taipan', lat: 3.0709, lon: 101.6312, seq: 12, zone: 4 },
  { code: 'KJ13', name: 'Ara Damansara', nameMy: 'Ara Damansara', lat: 3.1145, lon: 101.5934, seq: 13, zone: 3 },
  { code: 'KJ14', name: 'Lembah Subang', nameMy: 'Lembah Subang', lat: 3.1156, lon: 101.6019, seq: 14, zone: 3 },
  { code: 'KJ15', name: 'KL Sentral', nameMy: 'KL Sentral', lat: 3.1349, lon: 101.6866, seq: 15, zone: 1,
    address: 'Jalan Stesen Sentral, KL Sentral, 50470 Kuala Lumpur',
    facilities: ['wheelchair', 'parking', 'atm', 'food_court', 'taxi', 'luggage_storage'] },
  { code: 'KJ16', name: 'Pasar Seni', nameMy: 'Pasar Seni', lat: 3.1434, lon: 101.6953, seq: 16, zone: 1 },
  { code: 'KJ17', name: 'Masjid Jamek', nameMy: 'Masjid Jamek', lat: 3.1489, lon: 101.6964, seq: 17, zone: 1 },
  { code: 'KJ18', name: 'Dang Wangi', nameMy: 'Dang Wangi', lat: 3.1571, lon: 101.6969, seq: 18, zone: 1 },
  { code: 'KJ19', name: 'KLCC', nameMy: 'KLCC', lat: 3.1579, lon: 101.7120, seq: 19, zone: 1,
    address: 'Kuala Lumpur City Centre, 50088 Kuala Lumpur',
    facilities: ['wheelchair', 'atm', 'food_court', 'shopping'] },
  { code: 'KJ20', name: 'Ampang Park', nameMy: 'Ampang Park', lat: 3.1595, lon: 101.7180, seq: 20, zone: 1 },
  { code: 'KJ21', name: 'Jelatek', nameMy: 'Jelatek', lat: 3.1658, lon: 101.7205, seq: 21, zone: 2 },
  { code: 'KJ22', name: 'Dato\' Keramat', nameMy: 'Dato\' Keramat', lat: 3.1712, lon: 101.7280, seq: 22, zone: 2 },
  { code: 'KJ23', name: 'Damai', nameMy: 'Damai', lat: 3.1786, lon: 101.7340, seq: 23, zone: 2 },
  { code: 'KJ24', name: 'Sri Rampai', nameMy: 'Sri Rampai', lat: 3.1845, lon: 101.7391, seq: 24, zone: 2 },
  { code: 'KJ25', name: 'Sri Rampai Interchange', nameMy: 'Sri Rampai Interchange', lat: 3.1891, lon: 101.7430, seq: 25, zone: 2 },
  { code: 'KJ26', name: 'Wangsa Maju', nameMy: 'Wangsa Maju', lat: 3.1934, lon: 101.7476, seq: 26, zone: 2 },
  { code: 'KJ27', name: 'Setiawangsa', nameMy: 'Setiawangsa', lat: 3.1961, lon: 101.7511, seq: 27, zone: 2 },
  { code: 'KJ28', name: 'Gombak', nameMy: 'Gombak', lat: 3.2189, lon: 101.7544, seq: 28, zone: 3,
    address: 'Jalan Pahang, Gombak, Selangor', facilities: ['parking', 'bus_terminal'] },
];

// ─── Kajang Line Stations (subset of major ones) ───────────────────────────────
const KG_STATIONS = [
  { code: 'KG01', name: 'Sentul Timur', nameMy: 'Sentul Timur', lat: 3.1889, lon: 101.6944, seq: 1, zone: 2 },
  { code: 'KG04', name: 'Titiwangsa', nameMy: 'Titiwangsa', lat: 3.1751, lon: 101.6999, seq: 4, zone: 1 },
  { code: 'KG07', name: 'PWTC', nameMy: 'PWTC', lat: 3.1700, lon: 101.6970, seq: 7, zone: 1 },
  { code: 'KG08', name: 'Sultan Ismail', nameMy: 'Sultan Ismail', lat: 3.1623, lon: 101.6959, seq: 8, zone: 1 },
  { code: 'KG09', name: 'Chow Kit', nameMy: 'Chow Kit', lat: 3.1598, lon: 101.6963, seq: 9, zone: 1 },
  { code: 'KG10', name: 'Dang Wangi', nameMy: 'Dang Wangi', lat: 3.1571, lon: 101.6969, seq: 10, zone: 1 },
  { code: 'KG11', name: 'Masjid Jamek', nameMy: 'Masjid Jamek', lat: 3.1489, lon: 101.6964, seq: 11, zone: 1 },
  { code: 'KG12', name: 'Pasar Seni', nameMy: 'Pasar Seni', lat: 3.1434, lon: 101.6953, seq: 12, zone: 1 },
  { code: 'KG13', name: 'Plaza Rakyat', nameMy: 'Plaza Rakyat', lat: 3.1401, lon: 101.6995, seq: 13, zone: 1 },
  { code: 'KG14', name: 'Hang Tuah', nameMy: 'Hang Tuah', lat: 3.1349, lon: 101.7043, seq: 14, zone: 1 },
  { code: 'KG15', name: 'Pudu', nameMy: 'Pudu', lat: 3.1303, lon: 101.7099, seq: 15, zone: 1 },
  { code: 'KG16', name: 'Chan Sow Lin', nameMy: 'Chan Sow Lin', lat: 3.1175, lon: 101.7205, seq: 16, zone: 2 },
  { code: 'KG17', name: 'Cheras', nameMy: 'Cheras', lat: 3.1034, lon: 101.7261, seq: 17, zone: 2 },
  { code: 'KG18', name: 'Salak Selatan', nameMy: 'Salak Selatan', lat: 3.0921, lon: 101.7259, seq: 18, zone: 2 },
  { code: 'KG19', name: 'Terminal Bersepadu Selatan', nameMy: 'Terminal Bersepadu Selatan', lat: 3.0801, lon: 101.7248, seq: 19, zone: 3,
    address: 'Bandar Tasik Selatan, 57100 Kuala Lumpur', facilities: ['parking', 'bus_terminal', 'taxi'] },
  { code: 'KG28', name: 'Kajang', nameMy: 'Kajang', lat: 2.9942, lon: 101.7888, seq: 28, zone: 5,
    address: 'Jalan Semenyih, 43000 Kajang, Selangor', facilities: ['parking', 'bus_terminal'] },
];

// ─── MRT Putrajaya Line Stations (key stations) ───────────────────────────────
const MRT_PY_STATIONS = [
  { code: 'PY01', name: 'Kwasa Damansara', nameMy: 'Kwasa Damansara', lat: 3.1571, lon: 101.5716, seq: 1, zone: 5 },
  { code: 'PY07', name: 'Damansara Damai', nameMy: 'Damansara Damai', lat: 3.1802, lon: 101.5889, seq: 7, zone: 4 },
  { code: 'PY12', name: 'Muzium Negara', nameMy: 'Muzium Negara', lat: 3.1415, lon: 101.6868, seq: 12, zone: 1,
    facilities: ['wheelchair', 'atm'] },
  { code: 'PY13', name: 'Pasar Seni', nameMy: 'Pasar Seni', lat: 3.1434, lon: 101.6953, seq: 13, zone: 1 },
  { code: 'PY14', name: 'Merdeka', nameMy: 'Merdeka', lat: 3.1456, lon: 101.7013, seq: 14, zone: 1 },
  { code: 'PY15', name: 'Bukit Bintang', nameMy: 'Bukit Bintang', lat: 3.1466, lon: 101.7116, seq: 15, zone: 1,
    facilities: ['wheelchair', 'atm', 'shopping'] },
  { code: 'PY16', name: 'Tun Razak Exchange', nameMy: 'Tun Razak Exchange', lat: 3.1366, lon: 101.7171, seq: 16, zone: 1 },
  { code: 'PY35', name: 'Putrajaya Sentral', nameMy: 'Putrajaya Sentral', lat: 2.9289, lon: 101.6783, seq: 35, zone: 7,
    facilities: ['parking', 'taxi', 'food_court'] },
  { code: 'PY43', name: 'Cyberjaya Utara', nameMy: 'Cyberjaya Utara', lat: 2.9232, lon: 101.6605, seq: 43, zone: 8 },
];

// ─── Monorail Stations ────────────────────────────────────────────────────────
const MRL_STATIONS = [
  { code: 'MR01', name: 'KL Sentral', nameMy: 'KL Sentral', lat: 3.1349, lon: 101.6866, seq: 1, zone: 1 },
  { code: 'MR02', name: 'Maharajalela', nameMy: 'Maharajalela', lat: 3.1380, lon: 101.6935, seq: 2, zone: 1 },
  { code: 'MR03', name: 'Hang Tuah', nameMy: 'Hang Tuah', lat: 3.1349, lon: 101.7043, seq: 3, zone: 1 },
  { code: 'MR04', name: 'Imbi', nameMy: 'Imbi', lat: 3.1435, lon: 101.7098, seq: 4, zone: 1 },
  { code: 'MR05', name: 'Bukit Bintang', nameMy: 'Bukit Bintang', lat: 3.1466, lon: 101.7116, seq: 5, zone: 1,
    facilities: ['shopping'] },
  { code: 'MR06', name: 'Raja Chulan', nameMy: 'Raja Chulan', lat: 3.1502, lon: 101.7102, seq: 6, zone: 1 },
  { code: 'MR07', name: 'Bukit Nanas', nameMy: 'Bukit Nanas', lat: 3.1545, lon: 101.7076, seq: 7, zone: 1 },
  { code: 'MR08', name: 'Dang Wangi', nameMy: 'Dang Wangi', lat: 3.1571, lon: 101.6969, seq: 8, zone: 1 },
  { code: 'MR09', name: 'Chow Kit', nameMy: 'Chow Kit', lat: 3.1637, lon: 101.7011, seq: 9, zone: 1 },
  { code: 'MR10', name: 'Titiwangsa', nameMy: 'Titiwangsa', lat: 3.1751, lon: 101.6999, seq: 10, zone: 1 },
  { code: 'MR11', name: 'PWTC', nameMy: 'PWTC', lat: 3.1700, lon: 101.6970, seq: 11, zone: 1 },
  { code: 'MR12', name: 'Bank Rakyat - Sentul Timur', nameMy: 'Bank Rakyat-Sentul Timur', lat: 3.1823, lon: 101.6972, seq: 12, zone: 2 },
];

// ─── Alerts seed data ─────────────────────────────────────────────────────────
const ALERTS_SEED = [
  {
    title: 'KJ Line: Minor delays at Masjid Jamek',
    description: 'Passengers may experience minor delays of 5–10 minutes due to increased crowd at Masjid Jamek station. Please plan accordingly.',
    severity: 'INFO' as const,
    lineCode: 'KJ',
  },
  {
    title: 'MRT Putrajaya Line: Track maintenance this weekend',
    description: 'Scheduled track maintenance between Muzium Negara and Merdeka stations on Saturday 14 Jun, 00:30–05:00. Free shuttle buses will be provided.',
    severity: 'WARNING' as const,
    lineCode: 'MRT_PY',
  },
  {
    title: 'Kajang Line: Signal fault resolved',
    description: 'Signal fault at Chan Sow Lin station has been fully resolved. Services are back to normal frequency.',
    severity: 'INFO' as const,
    lineCode: 'KG',
  },
];

// ─── Seed helper ──────────────────────────────────────────────────────────────
async function upsertStation(
  s: { code: string; name: string; nameMy: string; lat: number; lon: number; facilities?: string[]; address?: string },
) {
  return prisma.station.upsert({
    where: { code: s.code },
    update: {},
    create: {
      code: s.code,
      name: s.name,
      nameMy: s.nameMy,
      latitude: s.lat,
      longitude: s.lon,
      address: s.address,
      facilities: s.facilities ?? [],
    },
  });
}

async function seedLineStations(
  lineCode: string,
  stations: { code: string; name: string; nameMy: string; lat: number; lon: number; seq: number; zone?: number; facilities?: string[]; address?: string }[],
) {
  const line = await prisma.transitLine.findUnique({ where: { code: lineCode } });
  if (!line) return;

  for (const s of stations) {
    const station = await upsertStation(s);
    await prisma.stationLine.upsert({
      where: { stationId_lineId: { stationId: station.id, lineId: line.id } },
      update: {},
      create: { stationId: station.id, lineId: line.id, sequence: s.seq, zoneNumber: s.zone },
    });
  }
}

async function seedDepartures(lineCode: string, stationCode: string, direction: string) {
  const station = await prisma.station.findUnique({ where: { code: stationCode } });
  const line = await prisma.transitLine.findUnique({ where: { code: lineCode } });
  if (!station || !line) return;

  const now = new Date();
  const departures = [];
  for (let i = 1; i <= 8; i++) {
    const scheduled = new Date(now.getTime() + i * 7 * 60 * 1000); // every 7 min
    departures.push({
      stationId: station.id,
      lineId: line.id,
      direction,
      scheduledAt: scheduled,
      status: 'ON_TIME' as const,
      platform: lineCode === 'KJ' ? 'Platform 1' : 'Platform 2',
    });
  }
  await prisma.departure.createMany({ data: departures, skipDuplicates: true });
}

// ─── Main seed ────────────────────────────────────────────────────────────────
async function main() {
  logger.info('🌱  Seeding database...');

  // Lines
  for (const line of LINES) {
    await prisma.transitLine.upsert({
      where: { code: line.code },
      update: {},
      create: line,
    });
  }
  logger.info(`  ✓ ${LINES.length} transit lines`);

  // KJ Line
  await seedLineStations('KJ', KJ_STATIONS);
  logger.info(`  ✓ ${KJ_STATIONS.length} KJ Line stations`);

  // Kajang Line
  await seedLineStations('KG', KG_STATIONS);
  logger.info(`  ✓ ${KG_STATIONS.length} Kajang Line stations`);

  // MRT Putrajaya
  await seedLineStations('MRT_PY', MRT_PY_STATIONS);
  logger.info(`  ✓ ${MRT_PY_STATIONS.length} MRT Putrajaya stations`);

  // Monorail
  await seedLineStations('MRL', MRL_STATIONS);
  logger.info(`  ✓ ${MRL_STATIONS.length} Monorail stations`);

  // Sample departures for KL Sentral
  await seedDepartures('KJ', 'KJ15', 'Putra Heights');
  await seedDepartures('KJ', 'KJ15', 'Gombak');
  await seedDepartures('MRL', 'MR01', 'Bank Rakyat-Sentul Timur');
  logger.info('  ✓ Sample departures for KL Sentral');

  // Alerts
  for (const alert of ALERTS_SEED) {
    const line = await prisma.transitLine.findUnique({ where: { code: alert.lineCode } });
    await prisma.transitAlert.create({
      data: {
        title: alert.title,
        description: alert.description,
        severity: alert.severity,
        lineId: line?.id,
        isActive: true,
      },
    });
  }
  logger.info(`  ✓ ${ALERTS_SEED.length} transit alerts`);

  logger.info('✅  Seed complete!');
}

main()
  .catch((err) => {
    logger.error('Seed failed', { err });
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
