import { prisma } from '../../config/database.js';
import { logger } from '../../shared/utils/logger.js';

export class DeviceTokenService {
  async registerToken(userId: string, token: string, platform = 'android') {
    logger.info({ userId, platform }, '[DeviceToken] Registering device push token');

    return prisma.deviceToken.upsert({
      where: { token },
      update: {
        userId,
        platform,
        updatedAt: new Date(),
      },
      create: {
        userId,
        token,
        platform,
      },
    });
  }

  async unregisterToken(userId: string, token: string) {
    logger.info({ userId }, '[DeviceToken] Unregistering device push token');

    return prisma.deviceToken.deleteMany({
      where: {
        userId,
        token,
      },
    });
  }

  async getUserTokens(userId: string): Promise<string[]> {
    const records = await prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true },
    });
    return records.map((r) => r.token);
  }

  async removeInvalidToken(token: string) {
    logger.warn({ token }, '[DeviceToken] Removing stale or unregistered push token');
    return prisma.deviceToken.deleteMany({
      where: { token },
    });
  }
}

export const deviceTokenService = new DeviceTokenService();
