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

  /**
   * Dispatches contribution reminders to active members who have not yet paid
   * for the given or current period, preventing duplicates and respecting payment status.
   */
  async dispatchContributionReminders(idirId?: string, periodYear?: number, periodMonth?: number) {
    const now = new Date();
    const targetYear = periodYear ?? now.getFullYear();
    const targetMonth = periodMonth ?? (now.getMonth() + 1);

    const startOfMonth = new Date(Date.UTC(targetYear, targetMonth - 1, 1));
    const endOfMonth = new Date(Date.UTC(targetYear, targetMonth, 0, 23, 59, 59, 999));

    const idirs = await prisma.idir.findMany({
      where: {
        ...(idirId && { id: idirId }),
        status: 'ACTIVE',
      },
      include: {
        settings: true,
      },
    });

    let remindersSent = 0;
    let alreadyPaidSkipped = 0;

    for (const idir of idirs) {
      const activeMemberships = await prisma.membership.findMany({
        where: { idirId: idir.id, status: 'ACTIVE' },
        include: {
          user: { select: { id: true, fullName: true, phoneNumber: true } },
        },
      });

      const duesAmount =
        idir.contributionAmount?.toNumber() ??
        idir.settings?.regularDuesAmount?.toNumber() ??
        100;

      for (const membership of activeMemberships) {
        // Check if member already has a confirmed payment in this period
        const paidContribution = await prisma.contribution.findFirst({
          where: {
            idirId: idir.id,
            membershipId: membership.id,
            status: 'CONFIRMED',
            isReversed: false,
            paymentDate: {
              gte: startOfMonth,
              lte: endOfMonth,
            },
          },
        });

        if (paidContribution) {
          alreadyPaidSkipped++;
          continue;
        }

        const idempotencyKey = `remind-dues-${idir.id}-${membership.id}-${targetYear}-${targetMonth}`;
        const monthNames = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        const monthName = monthNames[targetMonth - 1] || `${targetMonth}`;

        const res = await reliableNotificationDispatcher.dispatch({
          userId: membership.userId,
          title: `Contribution Reminder: ${idir.name}`,
          body: `Reminder: Contribution for ${monthName} ${targetYear} (${duesAmount} ETB) is due for ${idir.name}. Please pay to your Idir treasurer.`,
          type: NotificationType.PAYMENT_DUE,
          data: {
            idirId: idir.id,
            membershipId: membership.id,
            periodMonth: targetMonth,
            periodYear: targetYear,
            amount: duesAmount,
          },
          channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH, NotificationChannel.SMS],
          idempotencyKey,
        });

        if (res.inAppCreated) {
          remindersSent++;
        }
      }
    }

    logger.info(
      { idirsCount: idirs.length, remindersSent, alreadyPaidSkipped, targetYear, targetMonth },
      '[RemindersService] Completed contribution reminder scan'
    );

    return {
      idirsProcessed: idirs.length,
      remindersSent,
      alreadyPaidSkipped,
    };
  }
}

export const remindersService = new RemindersService();
