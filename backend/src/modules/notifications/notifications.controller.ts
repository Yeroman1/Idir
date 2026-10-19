import { Response, NextFunction } from 'express';
import { notificationsService } from './notifications.service.js';
import { sendSuccess, sendCreated } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';

export class NotificationsController {
  async createAnnouncement(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const announcement = await notificationsService.createAnnouncement(
        req.params.idirId,
        req.body,
        req.user!.id
      );
      return sendCreated(res, announcement, 'Announcement published successfully');
    } catch (error) {
      next(error);
    }
  }

  async listAnnouncements(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const announcements = await notificationsService.listAnnouncements(req.params.idirId);
      return sendSuccess(res, announcements);
    } catch (error) {
      next(error);
    }
  }

  async listMyNotifications(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const limit = req.query.limit ? Number(req.query.limit) : 50;
      const result = await notificationsService.listUserNotifications(req.user!.id, limit);
      return sendSuccess(res, result.items, 200, undefined, { unreadCount: result.unreadCount });
    } catch (error) {
      next(error);
    }
  }

  async markRead(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      await notificationsService.markNotificationRead(req.user!.id, req.params.notificationId);
      return sendSuccess(res, { markedRead: true });
    } catch (error) {
      next(error);
    }
  }

  async markAllRead(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      await notificationsService.markAllNotificationsRead(req.user!.id);
      return sendSuccess(res, { markedAllRead: true });
    } catch (error) {
      next(error);
    }
  }
}

export const notificationsController = new NotificationsController();
