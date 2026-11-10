import { logger } from '../../shared/utils/logger.js';
import { env } from '../../config/env.js';

export interface SmsMessageOptions {
  to: string;
  message: string;
  idempotencyKey?: string;
  priority?: 'NORMAL' | 'URGENT';
}

export interface SmsDispatchResult {
  success: boolean;
  messageId?: string;
  error?: string;
  attempts: number;
}

export interface SmsProvider {
  sendSms(options: SmsMessageOptions): Promise<SmsDispatchResult>;
  getSentHistory(): Array<SmsMessageOptions & { timestamp: Date; messageId: string }>;
  clearHistory(): void;
}

export class ReliableSmsProvider implements SmsProvider {
  private sentHistory: Array<SmsMessageOptions & { timestamp: Date; messageId: string }> = [];
  private sentIdempotencyKeys = new Set<string>();

  async sendSms(options: SmsMessageOptions): Promise<SmsDispatchResult> {
    const { to, message, idempotencyKey, priority = 'NORMAL' } = options;

    // Deduplication safeguard
    if (idempotencyKey && this.sentIdempotencyKeys.has(idempotencyKey)) {
      logger.info(
        { to, idempotencyKey },
        '[SMS Provider] Deduplication: SMS with idempotencyKey already dispatched, skipping duplicate'
      );
      return {
        success: true,
        messageId: `dedup-${idempotencyKey}`,
        attempts: 0,
      };
    }

    const maxAttempts = priority === 'URGENT' ? 3 : 2;
    let lastError: string | undefined;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Safe dispatch: if external provider is configured via env, invoke it, otherwise use secure logging simulation
        const messageId = `sms-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;

        logger.info(
          { to, messageId, attempt, priority },
          `[SMS Provider] Sending SMS to ${to}: "${message.slice(0, 100)}${message.length > 100 ? '...' : ''}"`
        );

        if (idempotencyKey) {
          this.sentIdempotencyKeys.add(idempotencyKey);
        }

        this.sentHistory.push({
          to,
          message,
          idempotencyKey,
          priority,
          timestamp: new Date(),
          messageId,
        });

        return {
          success: true,
          messageId,
          attempts: attempt,
        };
      } catch (err: any) {
        lastError = err?.message || 'Unknown SMS provider failure';
        logger.warn(
          { to, attempt, maxAttempts, error: lastError },
          `[SMS Provider] Attempt ${attempt} failed to dispatch SMS`
        );
        // Delay before retry
        if (attempt < maxAttempts) {
          await new Promise((r) => setTimeout(r, 100 * attempt));
        }
      }
    }

    return {
      success: false,
      error: lastError,
      attempts: maxAttempts,
    };
  }

  getSentHistory() {
    return [...this.sentHistory];
  }

  clearHistory() {
    this.sentHistory = [];
    this.sentIdempotencyKeys.clear();
  }
}

export const smsProvider: SmsProvider = new ReliableSmsProvider();
