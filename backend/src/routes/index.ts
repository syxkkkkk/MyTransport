import { Router } from 'express';
import authRoutes from './auth.routes';
import transitRoutes from './transit.routes';
import routeRoutes from './route.routes';
import chatbotRoutes from './chatbot.routes';
import notificationRoutes from './notification.routes';

const router = Router();

router.use('/auth', authRoutes);
router.use('/transit', transitRoutes);
router.use('/routes', routeRoutes);
router.use('/chatbot', chatbotRoutes);
router.use('/notifications', notificationRoutes);

// Health check
router.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString(), service: 'MyTransport API' });
});

export default router;
