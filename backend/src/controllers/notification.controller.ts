import { NextFunction, Request, Response } from 'express';
import { NotificationService } from '../services/notification.service';
import { sendSuccess } from '../utils/response';

export const NotificationController = {
  async getNotifications(req: Request, res: Response, next: NextFunction) {
    try {
      const unreadOnly = req.query.unread === 'true';
      const notifications = await NotificationService.getNotifications(req.user!.id, unreadOnly);
      sendSuccess(res, notifications);
    } catch (err) {
      next(err);
    }
  },

  async getUnreadCount(req: Request, res: Response, next: NextFunction) {
    try {
      const count = await NotificationService.getUnreadCount(req.user!.id);
      sendSuccess(res, { count });
    } catch (err) {
      next(err);
    }
  },

  async markRead(req: Request, res: Response, next: NextFunction) {
    try {
      const notif = await NotificationService.markRead(req.user!.id, req.params.id as string);
      sendSuccess(res, notif);
    } catch (err) {
      next(err);
    }
  },

  async markAllRead(req: Request, res: Response, next: NextFunction) {
    try {
      await NotificationService.markAllRead(req.user!.id);
      sendSuccess(res, null, { message: 'All notifications marked as read' });
    } catch (err) {
      next(err);
    }
  },
};
