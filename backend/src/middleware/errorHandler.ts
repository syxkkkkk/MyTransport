import { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';
import { ApiError } from '../utils/ApiError';
import { sendError } from '../utils/response';
import { logger } from '../utils/logger';

export function errorHandler(err: unknown, req: Request, res: Response, _next: NextFunction) {
  // Zod validation errors
  if (err instanceof ZodError) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'Validation failed', err.flatten().fieldErrors);
  }

  // Known API errors
  if (err instanceof ApiError) {
    if (err.statusCode >= 500) logger.error(`${err.statusCode} ${err.message}`, { stack: err.stack, path: req.path });
    return sendError(res, err.statusCode, err.code ?? 'API_ERROR', err.message, err.details);
  }

  // Unknown errors
  logger.error('Unhandled error', { err, path: req.path, method: req.method });
  return sendError(res, 500, 'INTERNAL_ERROR', 'An unexpected error occurred');
}

export function notFoundHandler(req: Request, res: Response) {
  return sendError(res, 404, 'NOT_FOUND', `Route ${req.method} ${req.path} not found`);
}
