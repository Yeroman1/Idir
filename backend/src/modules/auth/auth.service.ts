import crypto from 'crypto';
import { prisma } from '../../config/database.js';
import { hashPassword, comparePassword } from '../../shared/utils/password.js';
import {
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
  hashToken,
} from '../../shared/utils/jwt.js';
import {
  ConflictError,
  UnauthorizedError,
  NotFoundError,
} from '../../shared/errors/AppError.js';
import { RegisterInput, LoginInput, RefreshTokenInput } from './auth.validation.js';

export class AuthService {
  async register(input: RegisterInput, ipAddress?: string) {
    let existingUser = null;
    if (input.faydaId) {
      existingUser = await prisma.user.findFirst({
        where: {
          OR: [
            { faydaId: input.faydaId },
            { phoneNumber: input.phoneNumber },
          ],
        },
      });
    } else {
      existingUser = await prisma.user.findUnique({
        where: { phoneNumber: input.phoneNumber },
      });
    }

    const passwordHash = await hashPassword(input.password);

    let user;
    if (existingUser) {
      user = await prisma.user.update({
        where: { id: existingUser.id },
        data: {
          fullName: input.fullName,
          phoneNumber: input.phoneNumber,
          email: input.email ?? existingUser.email,
          passwordHash,
          preferredLanguage: input.preferredLanguage || existingUser.preferredLanguage,
          faydaId: input.faydaId ?? existingUser.faydaId,
          status: 'ACTIVE',
        },
        select: {
          id: true,
          fullName: true,
          phoneNumber: true,
          email: true,
          preferredLanguage: true,
          faydaId: true,
          status: true,
          isPlatformAdmin: true,
          createdAt: true,
          memberships: {
            include: {
              idir: {
                select: {
                  id: true,
                  name: true,
                  currency: true,
                  status: true,
                },
              },
            },
          },
        },
      });
    } else {
      user = await prisma.user.create({
        data: {
          fullName: input.fullName,
          phoneNumber: input.phoneNumber,
          email: input.email,
          passwordHash,
          preferredLanguage: input.preferredLanguage || 'am',
          faydaId: input.faydaId,
          status: 'ACTIVE',
        },
        select: {
          id: true,
          fullName: true,
          phoneNumber: true,
          email: true,
          preferredLanguage: true,
          faydaId: true,
          status: true,
          isPlatformAdmin: true,
          createdAt: true,
          memberships: {
            include: {
              idir: {
                select: {
                  id: true,
                  name: true,
                  currency: true,
                  status: true,
                },
              },
            },
          },
        },
      });
    }

    const tokenPayload = {
      userId: user.id,
      phoneNumber: user.phoneNumber,
      isPlatformAdmin: user.isPlatformAdmin,
    };

    const accessToken = generateAccessToken(tokenPayload);
    const refreshToken = generateRefreshToken(tokenPayload);
    const family = crypto.randomUUID();

    await prisma.refreshToken.create({
      data: {
        tokenHash: hashToken(refreshToken),
        userId: user.id,
        family,
        ipAddress,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
      },
    });

    return { user, tokens: { accessToken, refreshToken } };
  }

  async login(input: LoginInput, ipAddress?: string) {
    const raw = input.phoneNumber.trim().replace(/\s+/g, '');
    let normalizedPhone = raw;
    if (raw.startsWith('09') && raw.length === 10) {
      normalizedPhone = '+251' + raw.slice(1);
    } else if (raw.startsWith('9') && raw.length === 9) {
      normalizedPhone = '+251' + raw;
    }

    let user = await prisma.user.findUnique({
      where: { phoneNumber: raw },
      include: {
        memberships: {
          include: {
            idir: {
              select: {
                id: true,
                name: true,
                currency: true,
              },
            },
          },
        },
      },
    });

    if (!user) {
      user = await prisma.user.findFirst({
        where: {
          OR: [
            { phoneNumber: normalizedPhone },
            { faydaId: raw },
            { email: raw.toLowerCase() },
          ],
        },
        include: {
          memberships: {
            include: {
              idir: {
                select: {
                  id: true,
                  name: true,
                  currency: true,
                },
              },
            },
          },
        },
      });
    }

    if (!user) {
      throw new UnauthorizedError('Invalid phone number, Fayda ID, or password');
    }

    if (user.status !== 'ACTIVE') {
      throw new UnauthorizedError('User account is suspended or inactive');
    }

    const isMatch = await comparePassword(input.password, user.passwordHash);
    if (!isMatch) {
      throw new UnauthorizedError('Invalid phone number or password');
    }

    const tokenPayload = {
      userId: user.id,
      phoneNumber: user.phoneNumber,
      isPlatformAdmin: user.isPlatformAdmin,
    };

    const accessToken = generateAccessToken(tokenPayload);
    const refreshToken = generateRefreshToken(tokenPayload);
    const family = crypto.randomUUID();

    await prisma.refreshToken.create({
      data: {
        tokenHash: hashToken(refreshToken),
        userId: user.id,
        family,
        deviceInfo: input.deviceInfo,
        ipAddress,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
    });

    return {
      user: {
        id: user.id,
        fullName: user.fullName,
        phoneNumber: user.phoneNumber,
        email: user.email,
        preferredLanguage: user.preferredLanguage,
        faydaId: user.faydaId,
        status: user.status,
        isPlatformAdmin: user.isPlatformAdmin,
        createdAt: user.createdAt,
        memberships: user.memberships,
      },
      tokens: { accessToken, refreshToken },
    };
  }

  async refreshToken(input: RefreshTokenInput, ipAddress?: string) {
    let payload;
    try {
      payload = verifyRefreshToken(input.refreshToken);
    } catch {
      throw new UnauthorizedError('Invalid or expired refresh token');
    }

    const tokenHash = hashToken(input.refreshToken);
    const session = await prisma.refreshToken.findUnique({
      where: { tokenHash },
    });

    if (!session) {
      // Possible reuse attack: token not found
      throw new UnauthorizedError('Refresh token invalid or has been revoked');
    }

    if (session.isRevoked) {
      // Token reuse detected! Invalidate all tokens in this family for security
      await prisma.refreshToken.updateMany({
        where: { family: session.family },
        data: { isRevoked: true },
      });
      throw new UnauthorizedError('Security alert: Token reuse detected. Please log in again.');
    }

    if (new Date() > session.expiresAt) {
      throw new UnauthorizedError('Refresh token has expired');
    }

    // Revoke old token
    await prisma.refreshToken.update({
      where: { id: session.id },
      data: { isRevoked: true },
    });

    // Generate new rotated pair
    const tokenPayload = {
      userId: payload.userId,
      phoneNumber: payload.phoneNumber,
      isPlatformAdmin: payload.isPlatformAdmin,
    };

    const accessToken = generateAccessToken(tokenPayload);
    const newRefreshToken = generateRefreshToken(tokenPayload);

    await prisma.refreshToken.create({
      data: {
        tokenHash: hashToken(newRefreshToken),
        userId: payload.userId,
        family: session.family, // Maintain family for rotation lineage
        ipAddress,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
    });

    return { accessToken, refreshToken: newRefreshToken };
  }

  async logout(refreshTokenString: string) {
    if (!refreshTokenString) return;
    const tokenHash = hashToken(refreshTokenString);
    await prisma.refreshToken.updateMany({
      where: { tokenHash },
      data: { isRevoked: true },
    });
  }

  async getMe(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        fullName: true,
        phoneNumber: true,
        email: true,
        preferredLanguage: true,
        faydaId: true,
        status: true,
        isPlatformAdmin: true,
        createdAt: true,
        memberships: {
          include: {
            idir: {
              select: {
                id: true,
                name: true,
                currency: true,
                status: true,
              },
            },
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundError('User not found');
    }

    return user;
  }
}

export const authService = new AuthService();
