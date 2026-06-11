import { Prisma } from '@prisma/client';
import { prisma } from '../config/prisma';
import { ApiError } from '../utils/ApiError';
import type { PlanRouteBody, SaveLocationBody } from '../validations/route.schema';

interface RouteStep {
  type: 'walk' | 'transit';
  instruction: string;
  durationMinutes: number;
  distanceKm?: number;
  line?: { code: string; name: string; color: string };
  fromStation?: string;
  toStation?: string;
  stopsCount?: number;
}

export const RouteService = {
  /**
   * Very simplified route planning – in production you would integrate
   * a proper transit routing engine (e.g. OpenTripPlanner or HERE Routing API).
   * This implementation returns a plausible mock response based on the
   * straight-line distance between origin and destination.
   */
  async planRoute(data: PlanRouteBody, userId?: string) {
    const distKm = haversineKm(data.fromLat, data.fromLon, data.toLat, data.toLon);
    const durationMin = Math.round(distKm * 4 + 10); // ~4 min/km + 10 min overhead
    const fare = Math.min(Math.max(1.2, distKm * 0.25), 6.0); // RM 1.20 – 6.00

    const steps: RouteStep[] = [
      {
        type: 'walk',
        instruction: `Walk to nearest station from ${data.fromName}`,
        durationMinutes: 5,
        distanceKm: 0.35,
      },
      {
        type: 'transit',
        instruction: 'Take KJ Line towards Putra Heights',
        durationMinutes: Math.max(durationMin - 12, 5),
        line: { code: 'KJ', name: 'Kelana Jaya Line', color: '#E51937' },
        fromStation: 'KL Sentral',
        toStation: data.toName,
        stopsCount: Math.max(Math.round(distKm / 2), 2),
      },
      {
        type: 'walk',
        instruction: `Walk to ${data.toName}`,
        durationMinutes: 7,
        distanceKm: 0.45,
      },
    ];

    const route = await prisma.route.create({
      data: {
        fromName: data.fromName,
        fromLat: data.fromLat,
        fromLon: data.fromLon,
        toName: data.toName,
        toLat: data.toLat,
        toLon: data.toLon,
        durationMinutes: durationMin,
        distanceKm: Math.round(distKm * 10) / 10,
        fareMyR: Math.round(fare * 100) / 100,
        steps: steps as unknown as Prisma.InputJsonValue,
      },
    });

    if (userId) {
      await prisma.trip.create({ data: { userId, routeId: route.id, status: 'PLANNED' } });
    }

    return route;
  },

  async getSavedLocations(userId: string) {
    return prisma.savedLocation.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  },

  async saveLocation(userId: string, data: SaveLocationBody) {
    return prisma.savedLocation.create({ data: { userId, ...data } });
  },

  async deleteSavedLocation(userId: string, id: string) {
    const loc = await prisma.savedLocation.findFirst({ where: { id, userId } });
    if (!loc) throw ApiError.notFound('Saved location');
    await prisma.savedLocation.delete({ where: { id } });
  },

  async getTripHistory(userId: string) {
    return prisma.trip.findMany({
      where: { userId },
      include: { route: true },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  },

  async rateTrip(userId: string, tripId: string, rating: number, feedback?: string) {
    const trip = await prisma.trip.findFirst({ where: { id: tripId, userId } });
    if (!trip) throw ApiError.notFound('Trip');
    return prisma.trip.update({ where: { id: tripId }, data: { rating, feedback, status: 'COMPLETED' } });
  },
};

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
