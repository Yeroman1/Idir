import { prisma } from '../../config/database.js';
import { NotificationType, NotificationChannel } from '@prisma/client';
import { UpdatePreferencesInput } from './notifications.validation.js';

export class NotificationPreferencesService {
  async getPreferences(userId: string) {
    let pref = await prisma.notificationPreference.findUnique({
      where: { userId },
    });

    if (!pref) {
      pref = await prisma.notificationPreference.create({
        data: {
          userId,
          inAppEnabled: true,
          pushEnabled: true,
          smsEnabled: true,
          emailEnabled: true,
          reminderMeetings: true,
          reminderContributions: true,
          notifyAnnouncements: true,
          notifyGovernance: true,
          notifyAssistance: true,
          quietHoursEnabled: false,
          quietHoursStart: '22:00',
          quietHoursEnd: '07:00',
        },
      });
    }

    return pref;
  }

  async updatePreferences(userId: string, input: UpdatePreferencesInput) {
    return prisma.notificationPreference.upsert({
      where: { userId },
      update: {
        ...(input.inAppEnabled !== undefined && { inAppEnabled: input.inAppEnabled }),
        ...(input.pushEnabled !== undefined && { pushEnabled: input.pushEnabled }),
        ...(input.smsEnabled !== undefined && { smsEnabled: input.smsEnabled }),
        ...(input.emailEnabled !== undefined && { emailEnabled: input.emailEnabled }),
        ...(input.reminderMeetings !== undefined && { reminderMeetings: input.reminderMeetings }),
        ...(input.reminderContributions !== undefined && { reminderContributions: input.reminderContributions }),
        ...(input.notifyAnnouncements !== undefined && { notifyAnnouncements: input.notifyAnnouncements }),
        ...(input.notifyGovernance !== undefined && { notifyGovernance: input.notifyGovernance }),
        ...(input.notifyAssistance !== undefined && { notifyAssistance: input.notifyAssistance }),
        ...(input.quietHoursEnabled !== undefined && { quietHoursEnabled: input.quietHoursEnabled }),
        ...(input.quietHoursStart !== undefined && { quietHoursStart: input.quietHoursStart }),
        ...(input.quietHoursEnd !== undefined && { quietHoursEnd: input.quietHoursEnd }),
      },
      create: {
        userId,
        inAppEnabled: input.inAppEnabled ?? true,
        pushEnabled: input.pushEnabled ?? true,
        smsEnabled: input.smsEnabled ?? true,
        emailEnabled: input.emailEnabled ?? true,
        reminderMeetings: input.reminderMeetings ?? true,
        reminderContributions: input.reminderContributions ?? true,
        notifyAnnouncements: input.notifyAnnouncements ?? true,
        notifyGovernance: input.notifyGovernance ?? true,
        notifyAssistance: input.notifyAssistance ?? true,
        quietHoursEnabled: input.quietHoursEnabled ?? false,
        quietHoursStart: input.quietHoursStart ?? '22:00',
        quietHoursEnd: input.quietHoursEnd ?? '07:00',
      },
    });
  }

  async shouldDeliver(
    userId: string,
    channel: NotificationChannel,
    type: NotificationType,
    now: Date = new Date()
  ): Promise<{ allowed: boolean; reason?: string }> {
    // Urgent alerts and invitations always deliver regardless of category preference
    if (type === 'URGENT_ALERT') {
      return { allowed: true };
    }

    const pref = await this.getPreferences(userId);

    // 1. Channel check
    if (channel === 'IN_APP' && !pref.inAppEnabled) {
      return { allowed: false, reason: 'In-app notifications disabled in preferences' };
    }
    if (channel === 'PUSH' && !pref.pushEnabled) {
      return { allowed: false, reason: 'Push notifications disabled in preferences' };
    }
    if (channel === 'SMS' && !pref.smsEnabled) {
      return { allowed: false, reason: 'SMS notifications disabled in preferences' };
    }
    if (channel === 'EMAIL' && !pref.emailEnabled) {
      return { allowed: false, reason: 'Email notifications disabled in preferences' };
    }

    // 2. Category check
    if (type === 'MEETING_REMINDER' && !pref.reminderMeetings) {
      return { allowed: false, reason: 'Meeting reminders disabled in preferences' };
    }
    if (type === 'PAYMENT_DUE' && !pref.reminderContributions) {
      return { allowed: false, reason: 'Contribution reminders disabled in preferences' };
    }
    if (type === 'ANNOUNCEMENT' && !pref.notifyAnnouncements) {
      return { allowed: false, reason: 'Announcements disabled in preferences' };
    }
    if (type === 'GOVERNANCE' && !pref.notifyGovernance) {
      return { allowed: false, reason: 'Governance updates disabled in preferences' };
    }
    if (type === 'ASSISTANCE_UPDATE' && !pref.notifyAssistance) {
      return { allowed: false, reason: 'Assistance updates disabled in preferences' };
    }

    // 3. Quiet hours check for external push/SMS channels
    if (pref.quietHoursEnabled && (channel === 'PUSH' || channel === 'SMS')) {
      const isQuiet = this.isInQuietHours(pref.quietHoursStart, pref.quietHoursEnd, now);
      if (isQuiet) {
        return { allowed: false, reason: 'Delivery suppressed during quiet hours' };
      }
    }

    return { allowed: true };
  }

  isInQuietHours(start: string | null, end: string | null, date: Date): boolean {
    if (!start || !end) return false;

    const [startH, startM] = start.split(':').map(Number);
    const [endH, endM] = end.split(':').map(Number);

    const currentMinutes = date.getHours() * 60 + date.getMinutes();
    const startMinutes = startH * 60 + startM;
    const endMinutes = endH * 60 + endM;

    if (startMinutes <= endMinutes) {
      // e.g. 01:00 to 06:00
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Overnight e.g. 22:00 to 07:00
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }
}

export const notificationPreferencesService = new NotificationPreferencesService();
