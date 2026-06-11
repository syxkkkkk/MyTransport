import { Router } from 'express';
import { RouteController } from '../controllers/route.controller';
import { authenticate } from '../middleware/authenticate';
import { validate } from '../middleware/validate';
import { planRouteSchema, saveLocationSchema } from '../validations/route.schema';

const router = Router();

// Route planning (optional auth — saves trip if authenticated)
router.post('/plan', validate(planRouteSchema), RouteController.planRoute);

// Saved locations (all protected)
router.get('/saved-locations', authenticate, RouteController.getSavedLocations);
router.post('/saved-locations', authenticate, validate(saveLocationSchema), RouteController.saveLocation);
router.delete('/saved-locations/:id', authenticate, RouteController.deleteLocation);

// Trip history
router.get('/trips', authenticate, RouteController.getTripHistory);
router.patch('/trips/:tripId/rate', authenticate, RouteController.rateTrip);

export default router;
