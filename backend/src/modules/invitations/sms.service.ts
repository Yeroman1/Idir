import { logger } from '../../shared/utils/logger.js';

export interface SentSmsRecord {
  to: string;
  idirName: string;
  inviteUrl: string;
  timestamp: Date;
}

export interface SmsService {
  sendInvitationSms(to: string, idirName: string, inviteUrl: string): Promise<boolean>;
  getSentHistory(): SentSmsRecord[];
  clearHistory(): void;
}

/**
 * Development and testing SMS service that logs messages safely
 * and stores sent messages in-memory for testing assertions.
 */
export class FakeLoggingSmsService implements SmsService {
  private sentMessages: SentSmsRecord[] = [];

  async sendInvitationSms(to: string, idirName: string, inviteUrl: string): Promise<boolean> {
    const record: SentSmsRecord = {
      to,
      idirName,
      inviteUrl,
      timestamp: new Date(),
    };

    this.sentMessages.push(record);

    logger.info(
      { to, idirName, inviteUrl },
      `[SMS DISPATCH] Invitation to join "${idirName}" sent to ${to}. Link: ${inviteUrl}`
    );

    return true;
  }

  getSentHistory(): SentSmsRecord[] {
    return [...this.sentMessages];
  }

  clearHistory(): void {
    this.sentMessages = [];
  }
}

export const smsService: SmsService = new FakeLoggingSmsService();
