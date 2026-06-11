import { Prisma } from '@prisma/client';
import { prisma } from '../config/prisma';
import { ApiError } from '../utils/ApiError';

export const NotificationService = {
  async getNotifications(userId: string, unreadOnly = false) {
    return prisma.notification.findMany({
      where: { userId, ...(unreadOnly && { isRead: false }) },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  },

  async markRead(userId: string, notificationId: string) {
    const notif = await prisma.notification.findFirst({ where: { id: notificationId, userId } });
    if (!notif) throw ApiError.notFound('Notification');
    return prisma.notification.update({ where: { id: notificationId }, data: { isRead: true } });
  },

  async markAllRead(userId: string) {
    await prisma.notification.updateMany({ where: { userId, isRead: false }, data: { isRead: true } });
  },

  async getUnreadCount(userId: string) {
    return prisma.notification.count({ where: { userId, isRead: false } });
  },

  // Internal: create notification for a user (called by other services)
  async create(
    userId: string,
    title: string,
    body: string,
    type: 'TRIP_REMINDER' | 'TRANSIT_ALERT' | 'SERVICE_UPDATE' | 'PROMOTION' | 'SYSTEM',
    data?: Record<string, unknown>,
  ) {
    return prisma.notification.create({ data: { userId, title, body, type, data: data as Prisma.InputJsonValue } });
  },
};
