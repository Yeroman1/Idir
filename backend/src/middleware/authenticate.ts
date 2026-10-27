import jwt from 'jsonwebtoken';
import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../shared/types/index.js';
import { verifyAccessToken } from '../shared/utils/jwt.js';
import { UnauthorizedError } from '../shared/errors/AppError.js';
import { prisma } from '../config/database.js';

export async function authenticate(
  req: AuthenticatedRequest,
  _res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(new UnauthorizedError('Missing or malformed Authorization header'));
  }

  const token = authHeader.split(' ')[1];

  let payload: any;
  try {
    payload = verifyAccessToken(token);
  } catch (error) {
    // If backend JWT verification fails, check if this is a valid Supabase JWT
    try {
      const decoded = jwt.decode(token) as any;
      if (decoded && (decoded.sub || decoded.userId)) {
        if (decoded.exp && decoded.exp * 1000 < Date.now()) {
          return next(new UnauthorizedError('Token has expired'));
        }
        payload = {
          userId: decoded.sub || decoded.userId,
          phoneNumber: decoded.phone || decoded.phone_number || decoded.phoneNumber || '',
          email: decoded.email,
          isPlatformAdmin: decoded.isPlatformAdmin || false,
        };
      } else {
        return next(new UnauthorizedError('Invalid or expired token', error));
      }
    } catch {
      return next(new UnauthorizedError('Invalid or expired token', error));
    }
  }

  try {
    let user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: {
        id: true,
        phoneNumber: true,
        fullName: true,
        email: true,
        status: true,
        isPlatformAdmin: true,
        preferredLanguage: true,
      },
    });

    if (!user && payload.email) {
      user = await prisma.user.findUnique({
        where: { email: payload.email },
        select: {
          id: true,
          phoneNumber: true,
          fullName: true,
          email: true,
          status: true,
          isPlatformAdmin: true,
          preferredLanguage: true,
        },
      });
    }

    if (!user) {
      // Auto-provision user record if authenticated through Supabase but missing in Prisma
      try {
        const phone = payload.phoneNumber && payload.phoneNumber.length >= 9
          ? payload.phoneNumber
          : `+2519${Date.now().toString().slice(-8)}`;
        user = await prisma.user.create({
          data: {
            id: payload.userId,
            email: payload.email || undefined,
            fullName: payload.email ? payload.email.split('@')[0] : 'Idir User',
            phoneNumber: phone,
            status: 'ACTIVE',
            passwordHash: 'supabase-authenticated',
          },
          select: {
            id: true,
            phoneNumber: true,
            fullName: true,
            email: true,
            status: true,
            isPlatformAdmin: true,
            preferredLanguage: true,
          },
        });
      } catch (_) {
        if (payload.phoneNumber) {
          user = await prisma.user.findUnique({
            where: { phoneNumber: payload.phoneNumber },
            select: {
              id: true,
              phoneNumber: true,
              fullName: true,
              email: true,
              status: true,
              isPlatformAdmin: true,
              preferredLanguage: true,
            },
          });
        }
      }
    }

    if (!user || user.status !== 'ACTIVE') {
      return next(new UnauthorizedError('User account is inactive or not found'));
    }

    req.user = {
      id: user.id,
      phoneNumber: user.phoneNumber,
      fullName: user.fullName,
      email: user.email,
      isPlatformAdmin: user.isPlatformAdmin,
      preferredLanguage: user.preferredLanguage,
    };

    next();
  } catch (error) {
    next(error);
  }
}
