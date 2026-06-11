import { NextFunction, Request, Response } from 'express';
import { ChatbotService } from '../services/chatbot.service';
import { sendSuccess } from '../utils/response';
import type { SendMessageBody } from '../validations/chat.schema';

export const ChatbotController = {
  async sendMessage(req: Request, res: Response, next: NextFunction) {
    try {
      const { message, sessionId } = req.body as SendMessageBody;
      const result = await ChatbotService.sendMessage(req.user!.id, message, sessionId);
      sendSuccess(res, result, { statusCode: 201 });
    } catch (err) {
      next(err);
    }
  },

  async getSessions(req: Request, res: Response, next: NextFunction) {
    try {
      const sessions = await ChatbotService.getSessions(req.user!.id);
      sendSuccess(res, sessions);
    } catch (err) {
      next(err);
    }
  },

  async getSession(req: Request, res: Response, next: NextFunction) {
    try {
      const session = await ChatbotService.getSession(req.user!.id, req.params.sessionId as string);
      sendSuccess(res, session);
    } catch (err) {
      next(err);
    }
  },

  async deleteSession(req: Request, res: Response, next: NextFunction) {
    try {
      await ChatbotService.deleteSession(req.user!.id, req.params.sessionId as string);
      sendSuccess(res, null, { message: 'Session deleted' });
    } catch (err) {
      next(err);
    }
  },
};
