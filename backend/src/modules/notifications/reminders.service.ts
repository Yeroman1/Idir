import { prisma } from '../../config/database.js';
import { reliableNotificationDispatcher } from './reliable-dispatcher.service.js';
import { NotificationType, NotificationChannel } from '@prisma/client';
import { logger } from '../../shared/utils/logger.js';

export class RemindersService {
  /**
   * Dispatches upcoming meeting reminders for meetings scheduled within leadHours.
   */
  async dispatchMeetingReminders(idirId?: string, leadHours = 24) {
    const now = new Date();
    const windowEnd = new Date(now.getTime() + leadHours * 60 * 60 * 1000);

    const meetings = await prisma.meeting.findMany({
      where: {
        ...(idirId && { idirId }),
        status: 'SCHEDULED',
        scheduledAt: {
          gte: now,
          lte: windowEnd,
        },
      },
      include: {
        idir: { select: { id: true, name: true } },
      },
    });

    let dispatchedCount = 0;

    for (const meeting of meetings) {
      const activeMembers = await prisma.membership.findMany({
        where: { idirId: meeting.idirId, status: 'ACTIVE' },
        select: { userId: true },
      });

      for (const member of activeMembers) {
        const idempotencyKey = `remind-meeting-${meeting.id}-${leadHours}h-${member.userId}`;
        const res = await reliableNotificationDispatcher.dispatch({
          userId: member.userId,
          title: `Meeting Reminder: ${meeting.title}`,
          body: `Reminder: "${meeting.title}" for ${meeting.idir.name} takes place on ${meeting.scheduledAt.toLocaleDateString()} at ${meeting.location || 'Idir hall'}.`,
          type: NotificationType.MEETING_REMINDER,
          data: {
            idirId: meeting.idirId,
            meetingId: meeting.id,
            scheduledAt: meeting.scheduledAt.toISOString(),
          },
          channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH, NotificationChannel.SMS],
          idempotencyKey,
        });

        if (res.inAppCreated) dispatchedCount++;
      }
    }

    logger.info(
      { meetingCount: meetings.length, dispatchedCount, leadHours },
      '[RemindersService] Completed meeting reminder scan'
    );

    return { meetingsCount: meetings.length, dispatchedCount };
  }
}

export const remindersService = new RemindersService();
