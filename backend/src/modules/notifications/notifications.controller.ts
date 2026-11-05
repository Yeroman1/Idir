import { Response, NextFunction } from 'express';
import { notificationsService } from './notifications.service.js';
import { notificationPreferencesService } from './preferences.service.js';
import { deviceTokenService } from './device-token.service.js';
import { remindersService } from './reminders.service.js';
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

  async getMyPreferences(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const preferences = await notificationPreferencesService.getPreferences(req.user!.id);
      return sendSuccess(res, preferences);
    } catch (error) {
      next(error);
    }
  }

  async updateMyPreferences(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const preferences = await notificationPreferencesService.updatePreferences(
        req.user!.id,
        req.body
      );
      return sendSuccess(res, preferences, 200, 'Notification preferences updated successfully');
    } catch (error) {
      next(error);
    }
  }

  async registerDeviceToken(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { token, platform } = req.body;
      const record = await deviceTokenService.registerToken(req.user!.id, token, platform);
      return sendSuccess(res, record, 200, 'Device token registered successfully');
    } catch (error) {
      next(error);
    }
  }

  async unregisterDeviceToken(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { token } = req.body;
      await deviceTokenService.unregisterToken(req.user!.id, token);
      return sendSuccess(res, { unregistered: true }, 200, 'Device token unregistered successfully');
    } catch (error) {
      next(error);
    }
  }

  async dispatchReminders(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const idirId = req.params.idirId;
      const { type = 'ALL', leadHours = 24 } = req.body;

      let meetingResult: any = null;
      let contributionResult: any = null;

      if (type === 'ALL' || type === 'MEETINGS') {
        meetingResult = await remindersService.dispatchMeetingReminders(idirId, leadHours);
      }
      if (type === 'ALL' || type === 'CONTRIBUTIONS') {
        contributionResult = await remindersService.dispatchContributionReminders(idirId);
      }

      return sendSuccess(
        res,
        {
          meetingResult,
          contributionResult,
        },
        200,
        'Reminders processed and dispatched successfully'
      );
    } catch (error) {
      next(error);
    }
  }
}

export const notificationsController = new NotificationsController();
