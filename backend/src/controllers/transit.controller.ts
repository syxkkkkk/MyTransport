import { NextFunction, Request, Response } from 'express';
import { TransitService } from '../services/transit.service';
import { sendSuccess } from '../utils/response';

export const TransitController = {
  async getLines(req: Request, res: Response, next: NextFunction) {
    try {
      const lines = await TransitService.getAllLines();
      sendSuccess(res, lines);
    } catch (err) {
      next(err);
    }
  },

  async getLine(req: Request, res: Response, next: NextFunction) {
    try {
      const line = await TransitService.getLine((req.params.code as string).toUpperCase());
      sendSuccess(res, line);
    } catch (err) {
      next(err);
    }
  },

  async getStations(req: Request, res: Response, next: NextFunction) {
    try {
      const search = req.query.search as string | undefined;
      const stations = await TransitService.getAllStations(search);
      sendSuccess(res, stations);
    } catch (err) {
      next(err);
    }
  },

  async getStation(req: Request, res: Response, next: NextFunction) {
    try {
      const station = await TransitService.getStation((req.params.code as string).toUpperCase());
      sendSuccess(res, station);
    } catch (err) {
      next(err);
    }
  },

  async getDepartures(req: Request, res: Response, next: NextFunction) {
    try {
      const stationCode = req.params.stationCode as string;
      const lineCode = req.query.line as string | undefined;
      const departures = await TransitService.getDepartures(stationCode.toUpperCase(), lineCode?.toUpperCase());
      sendSuccess(res, departures);
    } catch (err) {
      next(err);
    }
  },

  async getAlerts(req: Request, res: Response, next: NextFunction) {
    try {
      const lineCode = req.query.line as string | undefined;
      const severity = req.query.severity as string | undefined;
      const alerts = await TransitService.getAlerts(lineCode?.toUpperCase(), severity?.toUpperCase());
      sendSuccess(res, alerts);
    } catch (err) {
      next(err);
    }
  },

  async getNearby(req: Request, res: Response, next: NextFunction) {
    try {
      const lat = parseFloat(req.query.lat as string);
      const lon = parseFloat(req.query.lon as string);
      const radius = req.query.radius ? parseFloat(req.query.radius as string) : 2;
      if (isNaN(lat) || isNaN(lon)) {
        return next(new Error('lat and lon query parameters are required'));
      }
      const stations = await TransitService.getNearbyStations(lat, lon, radius);
      sendSuccess(res, stations);
    } catch (err) {
      next(err);
    }
  },
};
