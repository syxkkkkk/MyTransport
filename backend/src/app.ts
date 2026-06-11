import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';

import { env } from './config/env';
import { logger } from './utils/logger';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';
import apiRoutes from './routes/index';

export function createApp() {
  const app = express();

  // ─── Security headers ────────────────────────────────────────────────────────
  app.use(helmet());

  // ─── CORS ────────────────────────────────────────────────────────────────────
  app.use(
    cors({
      origin: env.CORS_ORIGIN.split(','),
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    }),
  );

  // ─── Compression ─────────────────────────────────────────────────────────────
  app.use(compression());

  // ─── Body parsing ────────────────────────────────────────────────────────────
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));

  // ─── HTTP request logging ────────────────────────────────────────────────────
  if (env.NODE_ENV !== 'test') {
    app.use(
      morgan('combined', {
        stream: { write: (msg) => logger.http(msg.trim()) },
        skip: (req) => req.path === '/api/v1/health',
      }),
    );
  }

  // ─── Rate limiting ───────────────────────────────────────────────────────────
  const limiter = rateLimit({
    windowMs: env.RATE_LIMIT_WINDOW_MS,
    max: env.RATE_LIMIT_MAX,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: { code: 'RATE_LIMITED', message: 'Too many requests, please try again later' } },
  });
  app.use(limiter);

  // ─── API routes ──────────────────────────────────────────────────────────────
  app.use(env.API_PREFIX, apiRoutes);

  // ─── 404 & error handlers ────────────────────────────────────────────────────
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
