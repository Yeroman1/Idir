import { logger } from '../../shared/utils/logger.js';
import { deviceTokenService } from './device-token.service.js';

export interface PushMessageOptions {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, any>;
  idempotencyKey?: string;
  priority?: 'NORMAL' | 'URGENT';
}

export interface PushDispatchResult {
  success: boolean;
  tokensCount: number;
  deliveredCount: number;
  failedCount: number;
  skipped?: boolean;
  reason?: string;
  attempts: number;
}

export interface PushNotificationProvider {
  sendPush(
    tokens: string[],
    payload: { title: string; body: string; data?: Record<string, any> }
  ): Promise<{ successfulTokens: string[]; invalidTokens: string[] }>;
}

export class MockPushNotificationProvider implements PushNotificationProvider {
  private dispatched: Array<{ tokens: string[]; payload: any; timestamp: Date }> = [];

  async sendPush(
    tokens: string[],
    payload: { title: string; body: string; data?: Record<string, any> }
  ): Promise<{ successfulTokens: string[]; invalidTokens: string[] }> {
    this.dispatched.push({ tokens, payload, timestamp: new Date() });
    logger.info(
      { tokensCount: tokens.length, title: payload.title },
      `[Push Provider] Dispatched push message to ${tokens.length} device tokens`
    );
    return {
      successfulTokens: [...tokens],
      invalidTokens: [],
    };
  }

  getDispatched() {
    return [...this.dispatched];
  }

  clear() {
    this.dispatched = [];
  }
}

export class PushNotificationService {
  private provider: PushNotificationProvider;
  private sentIdempotencyKeys = new Set<string>();

  constructor(provider?: PushNotificationProvider) {
    this.provider = provider || new MockPushNotificationProvider();
  }

  async sendToUser(options: PushMessageOptions): Promise<PushDispatchResult> {
    const { userId, title, body, data, idempotencyKey, priority = 'NORMAL' } = options;

    if (idempotencyKey && this.sentIdempotencyKeys.has(idempotencyKey)) {
      logger.info(
        { userId, idempotencyKey },
        '[Push Service] Deduplication: Push message already sent with idempotencyKey'
      );
      return {
        success: true,
        tokensCount: 0,
        deliveredCount: 0,
        failedCount: 0,
        skipped: true,
        reason: 'Duplicate idempotency key',
        attempts: 0,
      };
    }

    const tokens = await deviceTokenService.getUserTokens(userId);
    if (!tokens || tokens.length === 0) {
      return {
        success: true,
        tokensCount: 0,
        deliveredCount: 0,
        failedCount: 0,
        skipped: true,
        reason: 'No registered device tokens for user',
        attempts: 0,
      };
    }

    const maxAttempts = priority === 'URGENT' ? 3 : 2;
    let attempts = 0;
    let deliveredCount = 0;
    let failedCount = 0;

    for (let i = 1; i <= maxAttempts; i++) {
      attempts = i;
      try {
        const { successfulTokens, invalidTokens } = await this.provider.sendPush(tokens, {
          title,
          body,
          data,
        });

        deliveredCount = successfulTokens.length;
        failedCount = invalidTokens.length;

        // Clean up invalid/stale tokens
        for (const badToken of invalidTokens) {
          await deviceTokenService.removeInvalidToken(badToken);
        }

        if (idempotencyKey) {
          this.sentIdempotencyKeys.add(idempotencyKey);
        }

        return {
          success: deliveredCount > 0 || tokens.length === 0,
          tokensCount: tokens.length,
          deliveredCount,
          failedCount,
          attempts,
        };
      } catch (err: any) {
        logger.warn(
          { userId, attempt: i, error: err?.message },
          '[Push Service] Push delivery attempt encountered transient error'
        );
        if (i < maxAttempts) {
          await new Promise((r) => setTimeout(r, 100 * i));
        }
      }
    }

    return {
      success: false,
      tokensCount: tokens.length,
      deliveredCount,
      failedCount: tokens.length,
      attempts,
    };
  }

  setProvider(provider: PushNotificationProvider) {
    this.provider = provider;
  }

  clearDeduplicationCache() {
    this.sentIdempotencyKeys.clear();
  }
}

export const pushNotificationService = new PushNotificationService();
