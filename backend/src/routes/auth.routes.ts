import { Router } from 'express';
import { AuthController } from '../controllers/auth.controller';
import { authenticate } from '../middleware/authenticate';
import { validate } from '../middleware/validate';
import { registerSchema, loginSchema, refreshSchema } from '../validations/auth.schema';

const router = Router();

// POST /api/v1/auth/register
router.post('/register', validate(registerSchema), AuthController.register);

// POST /api/v1/auth/login
router.post('/login', validate(loginSchema), AuthController.login);

// POST /api/v1/auth/refresh
router.post('/refresh', validate(refreshSchema), AuthController.refresh);

// POST /api/v1/auth/logout
router.post('/logout', validate(refreshSchema), AuthController.logout);

// GET /api/v1/auth/me  (protected)
router.get('/me', authenticate, AuthController.getProfile);

export default router;
