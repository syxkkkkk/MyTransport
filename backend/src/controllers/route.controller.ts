import { NextFunction, Request, Response } from 'express';
import { RouteService } from '../services/route.service';
import { sendSuccess } from '../utils/response';
import type { PlanRouteBody, SaveLocationBody } from '../validations/route.schema';

export const RouteController = {
  async planRoute(req: Request, res: Response, next: NextFunction) {
    try {
      const route = await RouteService.planRoute(req.body as PlanRouteBody, req.user?.id);
      sendSuccess(res, route, { statusCode: 201 });
    } catch (err) {
      next(err);
    }
  },

  async getSavedLocations(req: Request, res: Response, next: NextFunction) {
    try {
      const locations = await RouteService.getSavedLocations(req.user!.id);
      sendSuccess(res, locations);
    } catch (err) {
      next(err);
    }
  },

  async saveLocation(req: Request, res: Response, next: NextFunction) {
    try {
      const loc = await RouteService.saveLocation(req.user!.id, req.body as SaveLocationBody);
      sendSuccess(res, loc, { statusCode: 201 });
    } catch (err) {
      next(err);
    }
  },

  async deleteLocation(req: Request, res: Response, next: NextFunction) {
    try {
      await RouteService.deleteSavedLocation(req.user!.id, req.params.id as string);
      sendSuccess(res, null, { message: 'Location deleted' });
    } catch (err) {
      next(err);
    }
  },

  async getTripHistory(req: Request, res: Response, next: NextFunction) {
    try {
      const trips = await RouteService.getTripHistory(req.user!.id);
      sendSuccess(res, trips);
    } catch (err) {
      next(err);
    }
  },

  async rateTrip(req: Request, res: Response, next: NextFunction) {
    try {
      const { rating, feedback } = req.body as { rating: number; feedback?: string };
      const trip = await RouteService.rateTrip(req.user!.id, req.params.tripId as string, rating, feedback);
      sendSuccess(res, trip);
    } catch (err) {
      next(err);
    }
  },
};
