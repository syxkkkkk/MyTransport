import { NextFunction, Request, Response } from 'express';
import { AuthService } from '../services/auth.service';
import { sendSuccess } from '../utils/response';
import type { RegisterBody, LoginBody, RefreshBody } from '../validations/auth.schema';

export const AuthController = {
  async register(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await AuthService.register(req.body as RegisterBody);
      sendSuccess(res, result, { statusCode: 201, message: 'Registration successful' });
    } catch (err) {
      next(err);
    }
  },

  async login(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await AuthService.login(req.body as LoginBody);
      sendSuccess(res, result, { message: 'Login successful' });
    } catch (err) {
      next(err);
    }
  },

  async refresh(req: Request, res: Response, next: NextFunction) {
    try {
      const { refreshToken } = req.body as RefreshBody;
      const tokens = await AuthService.refresh(refreshToken);
      sendSuccess(res, tokens);
    } catch (err) {
      next(err);
    }
  },

  async logout(req: Request, res: Response, next: NextFunction) {
    try {
      const { refreshToken } = req.body as RefreshBody;
      await AuthService.logout(refreshToken);
      sendSuccess(res, null, { message: 'Logged out successfully' });
    } catch (err) {
      next(err);
    }
  },

  async getProfile(req: Request, res: Response, next: NextFunction) {
    try {
      const user = await AuthService.getProfile(req.user!.id);
      sendSuccess(res, user);
    } catch (err) {
      next(err);
    }
  },
};
