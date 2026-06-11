import { prisma } from '../config/prisma';
import { ApiError } from '../utils/ApiError';

export const TransitService = {
  async getAllLines() {
    return prisma.transitLine.findMany({
      where: { isActive: true },
      include: {
        _count: { select: { stations: true } },
      },
      orderBy: { code: 'asc' },
    });
  },

  async getLine(code: string) {
    const line = await prisma.transitLine.findUnique({
      where: { code },
      include: {
        stations: {
          include: { station: true },
          orderBy: { sequence: 'asc' },
        },
        alerts: { where: { isActive: true }, orderBy: { createdAt: 'desc' } },
      },
    });
    if (!line) throw ApiError.notFound('Transit line');
    return line;
  },

  async getAllStations(search?: string) {
    return prisma.station.findMany({
      where: {
        isActive: true,
        ...(search && { name: { contains: search, mode: 'insensitive' } }),
      },
      include: {
        lines: {
          include: { line: { select: { code: true, name: true, color: true } } },
        },
      },
      orderBy: { name: 'asc' },
    });
  },

  async getStation(code: string) {
    const station = await prisma.station.findUnique({
      where: { code },
      include: {
        lines: { include: { line: true }, orderBy: { sequence: 'asc' } },
        departures: {
          where: { scheduledAt: { gte: new Date() } },
          include: { line: { select: { code: true, name: true, color: true } } },
          orderBy: { scheduledAt: 'asc' },
          take: 20,
        },
      },
    });
    if (!station) throw ApiError.notFound('Station');
    return station;
  },

  async getDepartures(stationCode: string, lineCode?: string) {
    const station = await prisma.station.findUnique({ where: { code: stationCode } });
    if (!station) throw ApiError.notFound('Station');

    return prisma.departure.findMany({
      where: {
        stationId: station.id,
        scheduledAt: { gte: new Date() },
        ...(lineCode && { line: { code: lineCode } }),
      },
      include: {
        line: { select: { code: true, name: true, color: true } },
      },
      orderBy: { scheduledAt: 'asc' },
      take: 20,
    });
  },

  async getAlerts(lineCode?: string, severity?: string) {
    return prisma.transitAlert.findMany({
      where: {
        isActive: true,
        ...(lineCode && { line: { code: lineCode } }),
        ...(severity && { severity: severity as 'INFO' | 'WARNING' | 'CRITICAL' }),
      },
      include: {
        line: { select: { code: true, name: true, color: true } },
      },
      orderBy: [{ severity: 'desc' }, { createdAt: 'desc' }],
    });
  },

  async getNearbyStations(lat: number, lon: number, radiusKm = 2) {
    // Approx bounding box (1° lat ≈ 111 km)
    const deltaLat = radiusKm / 111;
    const deltaLon = radiusKm / (111 * Math.cos((lat * Math.PI) / 180));

    const stations = await prisma.station.findMany({
      where: {
        isActive: true,
        latitude: { gte: lat - deltaLat, lte: lat + deltaLat },
        longitude: { gte: lon - deltaLon, lte: lon + deltaLon },
      },
      include: {
        lines: { include: { line: { select: { code: true, name: true, color: true } } } },
      },
    });

    // Sort by actual distance and return with distance field
    return stations
      .map((s) => ({
        ...s,
        distanceKm: haversineKm(lat, lon, s.latitude, s.longitude),
      }))
      .filter((s) => s.distanceKm <= radiusKm)
      .sort((a, b) => a.distanceKm - b.distanceKm);
  },
};

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number) {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRad(deg: number) {
  return (deg * Math.PI) / 180;
}
