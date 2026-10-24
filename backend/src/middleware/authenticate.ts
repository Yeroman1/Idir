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

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch (error) {
    return next(new UnauthorizedError('Invalid or expired token', error));
  }

  try {
    const user = await prisma.user.findUnique({
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
