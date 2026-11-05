import { Router } from 'express';
import { notificationsController } from './notifications.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import {
  createAnnouncementSchema,
  updatePreferencesSchema,
  registerDeviceTokenSchema,
  unregisterDeviceTokenSchema,
} from './notifications.validation.js';

// Idir announcements router
const announcementsRouter = Router({ mergeParams: true });

announcementsRouter.use(authenticate);

announcementsRouter.post(
  '/',
  requireIdirRole(['CHAIRPERSON', 'TREASURER', 'SECRETARY']),
  validate({ body: createAnnouncementSchema }),
  notificationsController.createAnnouncement
);

announcementsRouter.get(
  '/',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  notificationsController.listAnnouncements
);

export const announcementRoutes = announcementsRouter;

// User notifications router
const userNotificationsRouter = Router();

userNotificationsRouter.use(authenticate);

userNotificationsRouter.get('/', notificationsController.listMyNotifications);
userNotificationsRouter.patch('/:notificationId/read', notificationsController.markRead);
userNotificationsRouter.post('/read-all', notificationsController.markAllRead);
userNotificationsRouter.get('/preferences', notificationsController.getMyPreferences);
userNotificationsRouter.put(
  '/preferences',
  validate({ body: updatePreferencesSchema }),
  notificationsController.updateMyPreferences
);
userNotificationsRouter.post(
  '/device-token',
  validate({ body: registerDeviceTokenSchema }),
  notificationsController.registerDeviceToken
);
userNotificationsRouter.delete(
  '/device-token',
  validate({ body: unregisterDeviceTokenSchema }),
  notificationsController.unregisterDeviceToken
);

export const notificationRoutes = userNotificationsRouter;
