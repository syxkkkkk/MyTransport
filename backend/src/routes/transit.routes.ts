import { Router } from 'express';
import { TransitController } from '../controllers/transit.controller';

const router = Router();

// Lines
router.get('/lines', TransitController.getLines);
router.get('/lines/:code', TransitController.getLine);

// Stations
router.get('/stations', TransitController.getStations);
router.get('/stations/nearby', TransitController.getNearby);
router.get('/stations/:code', TransitController.getStation);
router.get('/stations/:stationCode/departures', TransitController.getDepartures);

// Alerts
router.get('/alerts', TransitController.getAlerts);

export default router;
