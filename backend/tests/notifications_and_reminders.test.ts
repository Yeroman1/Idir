import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/config/database.js';
import { generateAccessToken } from '../src/shared/utils/jwt.js';
import { reliableNotificationDispatcher } from '../src/modules/notifications/reliable-dispatcher.service.js';
import { remindersService } from '../src/modules/notifications/reminders.service.js';
import { notificationPreferencesService } from '../src/modules/notifications/preferences.service.js';
import { deviceTokenService } from '../src/modules/notifications/device-token.service.js';
import { smsProvider } from '../src/modules/notifications/sms.provider.js';
import { pushNotificationService } from '../src/modules/notifications/push.service.js';
import { NotificationType, NotificationChannel, DeliveryStatus } from '@prisma/client';

vi.mock('../src/config/database.js', () => ({
  prisma: {
    user: { findUnique: vi.fn(), findFirst: vi.fn(), findMany: vi.fn() },
    idir: { findUnique: vi.fn(), findFirst: vi.fn(), findMany: vi.fn(), update: vi.fn() },
    membership: { findFirst: vi.fn(), findUnique: vi.fn(), create: vi.fn(), count: vi.fn(), update: vi.fn(), findMany: vi.fn() },
    meeting: { findMany: vi.fn(), create: vi.fn(), update: vi.fn(), findFirst: vi.fn() },
    contribution: { findFirst: vi.fn(), findMany: vi.fn(), create: vi.fn(), update: vi.fn() },
    announcement: { create: vi.fn(), findMany: vi.fn() },
    notification: { create: vi.fn(), findUnique: vi.fn(), findMany: vi.fn(), count: vi.fn(), updateMany: vi.fn(), createMany: vi.fn() },
    notificationPreference: { findUnique: vi.fn(), create: vi.fn(), upsert: vi.fn(), update: vi.fn() },
    deviceToken: { upsert: vi.fn(), deleteMany: vi.fn(), findMany: vi.fn() },
    notificationDelivery: { upsert: vi.fn(), create: vi.fn() },
    auditLog: { create: vi.fn() },
    $transaction: vi.fn((callback) => callback(prisma)),
  } as any,
}));

describe('Notifications, Preferences & Reminders Module', () => {
  const userId = 'user-uuid-100';
  const officerUserId = 'officer-uuid-200';
  const idirId = 'idir-uuid-500';

  let userToken: string;
  let officerToken: string;

  beforeEach(() => {
    vi.clearAllMocks();
    smsProvider.clearHistory();
    pushNotificationService.clearDeduplicationCache();

    userToken = generateAccessToken({
      userId,
      phoneNumber: '+251911111111',
      isPlatformAdmin: false,
    });

    officerToken = generateAccessToken({
      userId: officerUserId,
      phoneNumber: '+251922222222',
      isPlatformAdmin: false,
    });

    (prisma.user.findUnique as any).mockImplementation(({ where }: any) => {
      const id = where.id || (where.phoneNumber === '+251922222222' ? officerUserId : userId);
      return Promise.resolve({
        id,
        phoneNumber: id === officerUserId ? '+251922222222' : '+251911111111',
        status: 'ACTIVE',
        isPlatformAdmin: false,
      });
    });

    (prisma.notificationPreference.create as any).mockImplementation(({ data }: any) => {
      return Promise.resolve({
        id: 'pref-mock-id',
        ...data,
      });
    });
  });

  describe('1. In-App Notifications API', () => {
    it('GET /api/v1/notifications lists user notifications with unread count', async () => {
      const mockItems = [
        {
          id: 'n-1',
          userId,
          title: 'Upcoming Meeting',
          body: 'General meeting tomorrow at 10 AM',
          type: 'MEETING_REMINDER',
          readAt: null,
          createdAt: new Date(),
        },
      ];

      (prisma.notification.findMany as any).mockResolvedValue(mockItems);
      (prisma.notification.count as any).mockResolvedValue(1);

      const res = await request(app)
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.meta.unreadCount).toBe(1);
    });

    it('PATCH /api/v1/notifications/:id/read marks notification as read', async () => {
      (prisma.notification.updateMany as any).mockResolvedValue({ count: 1 });

      const res = await request(app)
        .patch('/api/v1/notifications/n-1/read')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.markedRead).toBe(true);
      expect(prisma.notification.updateMany).toHaveBeenCalledWith({
        where: { id: 'n-1', userId },
        data: expect.objectContaining({ readAt: expect.any(Date) }),
      });
    });

    it('POST /api/v1/notifications/read-all marks all notifications as read', async () => {
      (prisma.notification.updateMany as any).mockResolvedValue({ count: 3 });

      const res = await request(app)
        .post('/api/v1/notifications/read-all')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.markedAllRead).toBe(true);
      expect(prisma.notification.updateMany).toHaveBeenCalledWith({
        where: { userId, readAt: null },
        data: expect.objectContaining({ readAt: expect.any(Date) }),
      });
    });
  });

  describe('2. Notification Preferences API', () => {
    it('GET /api/v1/notifications/preferences returns default user preferences', async () => {
      (prisma.notificationPreference.findUnique as any).mockResolvedValue(null);
      (prisma.notificationPreference.create as any).mockResolvedValue({
        id: 'pref-1',
        userId,
        inAppEnabled: true,
        pushEnabled: true,
        smsEnabled: true,
        reminderMeetings: true,
        reminderContributions: true,
        quietHoursEnabled: false,
      });

      const res = await request(app)
        .get('/api/v1/notifications/preferences')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.inAppEnabled).toBe(true);
      expect(res.body.data.pushEnabled).toBe(true);
    });

    it('PUT /api/v1/notifications/preferences updates preferences with valid quiet hours', async () => {
      (prisma.notificationPreference.upsert as any).mockResolvedValue({
        id: 'pref-1',
        userId,
        inAppEnabled: true,
        pushEnabled: false,
        smsEnabled: true,
        reminderMeetings: false,
        reminderContributions: true,
        quietHoursEnabled: true,
        quietHoursStart: '23:00',
        quietHoursEnd: '06:00',
      });

      const res = await request(app)
        .put('/api/v1/notifications/preferences')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          pushEnabled: false,
          reminderMeetings: false,
          quietHoursEnabled: true,
          quietHoursStart: '23:00',
          quietHoursEnd: '06:00',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.pushEnabled).toBe(false);
      expect(res.body.data.reminderMeetings).toBe(false);
      expect(res.body.data.quietHoursEnabled).toBe(true);
    });

    it('PUT /api/v1/notifications/preferences rejects invalid time format for quiet hours', async () => {
      const res = await request(app)
        .put('/api/v1/notifications/preferences')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          quietHoursStart: 'invalid-time',
        });

      expect(res.status).toBe(422);
    });
  });

  describe('3. Device Token Push Management API', () => {
    it('POST /api/v1/notifications/device-token registers device push token', async () => {
      (prisma.deviceToken.upsert as any).mockResolvedValue({
        id: 'token-1',
        userId,
        token: 'fcm-device-token-1234567890',
        platform: 'android',
      });

      const res = await request(app)
        .post('/api/v1/notifications/device-token')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          token: 'fcm-device-token-1234567890',
          platform: 'android',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.token).toBe('fcm-device-token-1234567890');
    });

    it('DELETE /api/v1/notifications/device-token unregisters device push token', async () => {
      (prisma.deviceToken.deleteMany as any).mockResolvedValue({ count: 1 });

      const res = await request(app)
        .delete('/api/v1/notifications/device-token')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          token: 'fcm-device-token-1234567890',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.unregistered).toBe(true);
    });
  });

  describe('4. Reliable Notification Dispatcher & Idempotency Safeguards', () => {
    it('dispatches in-app notification when enabled and creates delivery record', async () => {
      (prisma.notification.findUnique as any).mockResolvedValue(null);
      (prisma.notificationPreference.findUnique as any).mockResolvedValue({
        userId,
        inAppEnabled: true,
        reminderMeetings: true,
        pushEnabled: false,
        smsEnabled: false,
      });
      (prisma.notification.create as any).mockResolvedValue({
        id: 'notif-100',
        userId,
        title: 'Meeting Scheduled',
        body: 'Details here',
        type: 'MEETING_REMINDER',
      });

      const result = await reliableNotificationDispatcher.dispatch({
        userId,
        title: 'Meeting Scheduled',
        body: 'Details here',
        type: NotificationType.MEETING_REMINDER,
        channels: [NotificationChannel.IN_APP],
        idempotencyKey: 'test-idemp-001',
      });

      expect(result.inAppCreated).toBe(true);
      expect(result.duplicateSkipped).toBe(false);
      expect(prisma.notification.create).toHaveBeenCalled();
    });

    it('skips duplicate notification creation when idempotencyKey already exists', async () => {
      (prisma.notification.findUnique as any).mockResolvedValue({
        id: 'existing-notif-999',
        userId,
        idempotencyKey: 'dup-key-1',
      });

      const result = await reliableNotificationDispatcher.dispatch({
        userId,
        title: 'Duplicate Event',
        body: 'Should not create duplicate',
        type: NotificationType.ANNOUNCEMENT,
        channels: [NotificationChannel.IN_APP],
        idempotencyKey: 'dup-key-1',
      });

      expect(result.inAppCreated).toBe(false);
      expect(result.duplicateSkipped).toBe(true);
      expect(result.notificationId).toBe('existing-notif-999');
      expect(prisma.notification.create).not.toHaveBeenCalled();
    });

    it('suppresses category when user preference disabled, but urgent alert bypasses', async () => {
      // User disabled meeting reminders
      (prisma.notificationPreference.findUnique as any).mockResolvedValue({
        userId,
        inAppEnabled: true,
        reminderMeetings: false,
      });

      const checkMeeting = await notificationPreferencesService.shouldDeliver(
        userId,
        NotificationChannel.IN_APP,
        NotificationType.MEETING_REMINDER
      );
      expect(checkMeeting.allowed).toBe(false);

      // Urgent alert bypasses
      const checkUrgent = await notificationPreferencesService.shouldDeliver(
        userId,
        NotificationChannel.IN_APP,
        NotificationType.URGENT_ALERT
      );
      expect(checkUrgent.allowed).toBe(true);
    });
  });

  describe('5. Contribution Reminders & Meeting Reminders Scheduler', () => {
    it('dispatchMeetingReminders sends reminders to active members for upcoming meetings', async () => {
      const now = new Date();
      const scheduledTime = new Date(now.getTime() + 2 * 60 * 60 * 1000); // 2 hours from now

      (prisma.meeting.findMany as any).mockResolvedValue([
        {
          id: 'meet-1',
          idirId,
          title: 'Monthly Assembly',
          location: 'Hall A',
          scheduledAt: scheduledTime,
          idir: { id: idirId, name: 'Bole Medhanealem Idir' },
        },
      ]);

      (prisma.membership.findMany as any).mockResolvedValue([
        { userId: 'user-member-1' },
        { userId: 'user-member-2' },
      ]);

      (prisma.notification.findUnique as any).mockResolvedValue(null);
      (prisma.notificationPreference.findUnique as any).mockResolvedValue({
        inAppEnabled: true,
        reminderMeetings: true,
      });
      (prisma.notification.create as any).mockResolvedValue({ id: 'notif-meet' });

      const res = await remindersService.dispatchMeetingReminders(idirId, 24);

      expect(res.meetingsCount).toBe(1);
      expect(res.dispatchedCount).toBe(2);
    });

    it('dispatchContributionReminders avoids sending reminders for members who already paid', async () => {
      (prisma.idir.findMany as any).mockResolvedValue([
        {
          id: idirId,
          name: 'Yeka Idir',
          contributionAmount: { toNumber: () => 150 },
        },
      ]);

      (prisma.membership.findMany as any).mockResolvedValue([
        { id: 'mem-paid', userId: 'user-paid' },
        { id: 'mem-unpaid', userId: 'user-unpaid' },
      ]);

      // mem-paid has confirmed contribution
      (prisma.contribution.findFirst as any).mockImplementation(({ where }: any) => {
        if (where.membershipId === 'mem-paid') {
          return Promise.resolve({ id: 'contrib-1', status: 'CONFIRMED' });
        }
        return Promise.resolve(null);
      });

      (prisma.notification.findUnique as any).mockResolvedValue(null);
      (prisma.notificationPreference.findUnique as any).mockResolvedValue({
        inAppEnabled: true,
        reminderContributions: true,
      });
      (prisma.notification.create as any).mockResolvedValue({ id: 'notif-due' });

      const res = await remindersService.dispatchContributionReminders(idirId);

      expect(res.idirsProcessed).toBe(1);
      expect(res.alreadyPaidSkipped).toBe(1);
      expect(res.remindersSent).toBe(1);
    });

    it('POST /api/v1/idirs/:idirId/announcements/dispatch-reminders allows authorized officer to trigger reminders', async () => {
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: 'mem-off',
        userId: officerUserId,
        idirId,
        role: 'CHAIRPERSON',
        status: 'ACTIVE',
      });

      (prisma.meeting.findMany as any).mockResolvedValue([]);
      (prisma.idir.findMany as any).mockResolvedValue([]);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/announcements/dispatch-reminders`)
        .set('Authorization', `Bearer ${officerToken}`)
        .send({
          type: 'ALL',
          leadHours: 48,
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('meetingResult');
      expect(res.body.data).toHaveProperty('contributionResult');
    });

    it('POST /api/v1/idirs/:idirId/announcements/dispatch-reminders rejects regular member from triggering reminders', async () => {
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: 'mem-reg',
        userId,
        idirId,
        role: 'MEMBER',
        status: 'ACTIVE',
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/announcements/dispatch-reminders`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          type: 'ALL',
        });

      expect(res.status).toBe(403);
    });
  });
});
