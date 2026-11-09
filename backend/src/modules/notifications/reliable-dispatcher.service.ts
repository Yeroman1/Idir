import { prisma } from '../../config/database.js';
import { NotificationType, NotificationChannel, DeliveryStatus } from '@prisma/client';
import { notificationPreferencesService } from './preferences.service.js';
import { pushNotificationService } from './push.service.js';
import { smsProvider } from './sms.provider.js';
import { logger } from '../../shared/utils/logger.js';

export interface DispatchNotificationInput {
  userId: string;
  title: string;
  body: string;
  type: NotificationType;
  data?: Record<string, any>;
  channels?: NotificationChannel[];
  idempotencyKey?: string;
  priority?: 'NORMAL' | 'URGENT';
}

export interface DispatchNotificationResult {
  notificationId?: string;
  inAppCreated: boolean;
  duplicateSkipped: boolean;
  channelsDispatched: NotificationChannel[];
}

export class ReliableNotificationDispatcher {
  async dispatch(input: DispatchNotificationInput): Promise<DispatchNotificationResult> {
    const {
      userId,
      title,
      body,
      type,
      data,
      channels = [NotificationChannel.IN_APP, NotificationChannel.PUSH],
      idempotencyKey,
      priority = 'NORMAL',
    } = input;

    // 1. Idempotency safeguard for in-app notification
    if (idempotencyKey) {
      const existing = await prisma.notification.findUnique({
        where: { idempotencyKey },
      });
      if (existing) {
        logger.info(
          { userId, idempotencyKey, notificationId: existing.id },
          '[NotificationDispatcher] Notification with idempotencyKey already exists, skipping duplicate creation'
        );
        return {
          notificationId: existing.id,
          inAppCreated: false,
          duplicateSkipped: true,
          channelsDispatched: [],
        };
      }
    }

    // 2. In-App Notification check & creation
    let notificationId: string | undefined;
    let inAppCreated = false;

    if (channels.includes(NotificationChannel.IN_APP)) {
      const inAppCheck = await notificationPreferencesService.shouldDeliver(
        userId,
        NotificationChannel.IN_APP,
        type
      );

      if (inAppCheck.allowed) {
        try {
          const notification = await prisma.notification.create({
            data: {
              userId,
              title,
              body,
              type,
              data: data || undefined,
              idempotencyKey: idempotencyKey || undefined,
            },
          });
          notificationId = notification.id;
          inAppCreated = true;

          // Record in-app delivery
          await this.recordDelivery(
            notification.id,
            NotificationChannel.IN_APP,
            DeliveryStatus.SENT,
            userId,
            1,
            undefined,
            idempotencyKey ? `inapp-${idempotencyKey}` : undefined
          );
        } catch (err: any) {
          logger.error(
            { userId, error: err?.message },
            '[NotificationDispatcher] Failed to create in-app notification'
          );
        }
      } else {
        logger.debug(
          { userId, reason: inAppCheck.reason },
          '[NotificationDispatcher] In-app notification skipped due to preferences'
        );
      }
    }

    // 3. Asynchronously dispatch external channels (Non-blocking)
    const externalChannels = channels.filter((c) => c !== NotificationChannel.IN_APP);
    if (externalChannels.length > 0) {
      // Fire-and-forget background execution
      queueMicrotask(() => {
        this.dispatchExternalChannels({
          userId,
          notificationId,
          title,
          body,
          type,
          data,
          channels: externalChannels,
          idempotencyKey,
          priority,
        }).catch((err) => {
          logger.warn(
            { userId, error: err?.message },
            '[NotificationDispatcher] Background external dispatch error'
          );
        });
      });
    }

    return {
      notificationId,
      inAppCreated,
      duplicateSkipped: false,
      channelsDispatched: inAppCreated ? [NotificationChannel.IN_APP] : [],
    };
  }

  private async dispatchExternalChannels(params: {
    userId: string;
    notificationId?: string;
    title: string;
    body: string;
    type: NotificationType;
    data?: Record<string, any>;
    channels: NotificationChannel[];
    idempotencyKey?: string;
    priority: 'NORMAL' | 'URGENT';
  }) {
    const {
      userId,
      notificationId,
      title,
      body,
      type,
      data,
      channels,
      idempotencyKey,
      priority,
    } = params;

    // Push notification channel
    if (channels.includes(NotificationChannel.PUSH)) {
      const pushCheck = await notificationPreferencesService.shouldDeliver(
        userId,
        NotificationChannel.PUSH,
        type
      );

      if (pushCheck.allowed) {
        try {
          const pushResult = await pushNotificationService.sendToUser({
            userId,
            title,
            body,
            data,
            idempotencyKey: idempotencyKey ? `push-${idempotencyKey}` : undefined,
            priority,
          });

          if (notificationId) {
            await this.recordDelivery(
              notificationId,
              NotificationChannel.PUSH,
              pushResult.success ? DeliveryStatus.SENT : DeliveryStatus.FAILED,
              userId,
              pushResult.attempts,
              pushResult.reason,
              idempotencyKey ? `push-${idempotencyKey}` : undefined
            );
          }
        } catch (err: any) {
          logger.warn({ userId, error: err?.message }, '[NotificationDispatcher] Push delivery error');
        }
      }
    }

    // SMS notification channel
    if (channels.includes(NotificationChannel.SMS)) {
      const smsCheck = await notificationPreferencesService.shouldDeliver(
        userId,
        NotificationChannel.SMS,
        type
      );

      if (smsCheck.allowed) {
        try {
          const user = await prisma.user.findUnique({
            where: { id: userId },
            select: { phoneNumber: true },
          });

          if (user?.phoneNumber) {
            const smsResult = await smsProvider.sendSms({
              to: user.phoneNumber,
              message: `${title}: ${body}`,
              idempotencyKey: idempotencyKey ? `sms-${idempotencyKey}` : undefined,
              priority,
            });

            if (notificationId) {
              await this.recordDelivery(
                notificationId,
                NotificationChannel.SMS,
                smsResult.success ? DeliveryStatus.SENT : DeliveryStatus.FAILED,
                user.phoneNumber,
                smsResult.attempts,
                smsResult.error,
                idempotencyKey ? `sms-${idempotencyKey}` : undefined
              );
            }
          }
        } catch (err: any) {
          logger.warn({ userId, error: err?.message }, '[NotificationDispatcher] SMS delivery error');
        }
      }
    }
  }

  private async recordDelivery(
    notificationId: string,
    channel: NotificationChannel,
    status: DeliveryStatus,
    recipient: string,
    attempts: number,
    error?: string,
    idempotencyKey?: string
  ) {
    try {
      if (idempotencyKey) {
        await prisma.notificationDelivery.upsert({
          where: { idempotencyKey },
          update: {
            status,
            attempts,
            error: error || null,
            lastAttemptAt: new Date(),
          },
          create: {
            notificationId,
            channel,
            status,
            recipient,
            attempts,
            error: error || null,
            idempotencyKey,
            lastAttemptAt: new Date(),
          },
        });
      } else {
        await prisma.notificationDelivery.create({
          data: {
            notificationId,
            channel,
            status,
            recipient,
            attempts,
            error: error || null,
            lastAttemptAt: new Date(),
          },
        });
      }
    } catch (err: any) {
      logger.warn(
        { notificationId, channel, error: err?.message },
        '[NotificationDispatcher] Could not record notification delivery'
      );
    }
  }
}

export const reliableNotificationDispatcher = new ReliableNotificationDispatcher();
