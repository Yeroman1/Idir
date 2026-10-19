import { prisma } from '../../config/database.js';
import { CreateAnnouncementInput } from './notifications.validation.js';

export class NotificationsService {
  async createAnnouncement(
    idirId: string,
    input: CreateAnnouncementInput,
    actorId: string
  ) {
    const announcement = await prisma.announcement.create({
      data: {
        idirId,
        title: input.title,
        body: input.body,
        priority: input.priority || 'NORMAL',
        target: input.target || 'ALL',
        isPinned: input.isPinned ?? false,
        createdById: actorId,
      },
      include: {
        createdBy: { select: { id: true, fullName: true } },
      },
    });

    // Broadcast notifications to all active members of this Idir
    const activeMembers = await prisma.membership.findMany({
      where: { idirId, status: 'ACTIVE' },
      select: { userId: true },
    });

    if (activeMembers.length > 0) {
      await prisma.notification.createMany({
        data: activeMembers.map((m) => ({
          userId: m.userId,
          title: `Announcement: ${input.title}`,
          body: input.body.slice(0, 150),
          type: 'ANNOUNCEMENT',
          data: { idirId, announcementId: announcement.id },
        })),
      });
    }

    return announcement;
  }

  async listAnnouncements(idirId: string) {
    return prisma.announcement.findMany({
      where: { idirId },
      orderBy: [{ isPinned: 'desc' }, { publishedAt: 'desc' }],
      include: {
        createdBy: { select: { id: true, fullName: true } },
      },
    });
  }

  async listUserNotifications(userId: string, limit = 50) {
    const [notifications, unreadCount] = await Promise.all([
      prisma.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: limit,
      }),
      prisma.notification.count({
        where: { userId, readAt: null },
      }),
    ]);

    return {
      items: notifications,
      unreadCount,
    };
  }

  async markNotificationRead(userId: string, notificationId: string) {
    return prisma.notification.updateMany({
      where: { id: notificationId, userId },
      data: { readAt: new Date() },
    });
  }

  async markAllNotificationsRead(userId: string) {
    return prisma.notification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
  }
}

export const notificationsService = new NotificationsService();
