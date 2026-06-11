import { Response } from 'express';

interface SuccessPayload<T> {
  success: true;
  data: T;
  message?: string;
  meta?: Record<string, unknown>;
}

interface ErrorPayload {
  success: false;
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
}

export function sendSuccess<T>(
  res: Response,
  data: T,
  options: { statusCode?: number; message?: string; meta?: Record<string, unknown> } = {},
) {
  const { statusCode = 200, message, meta } = options;
  const payload: SuccessPayload<T> = {
    success: true,
    data,
    ...(message !== undefined ? { message } : {}),
    ...(meta !== undefined ? { meta } : {}),
  };
  return res.status(statusCode).json(payload);
}

export function sendError(res: Response, statusCode: number, code: string, message: string, details?: unknown) {
  const payload: ErrorPayload = {
    success: false,
    error: { code, message, ...(details !== undefined ? { details } : {}) },
  };
  return res.status(statusCode).json(payload);
}
