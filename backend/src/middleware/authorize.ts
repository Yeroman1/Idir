import { Response, NextFunction } from 'express';
import { MembershipRole } from '@prisma/client';
import { AuthenticatedRequest } from '../shared/types/index.js';
import { ForbiddenError, NotFoundError } from '../shared/errors/AppError.js';
import { prisma } from '../config/database.js';
import { logger } from '../shared/utils/logger.js';

export function requirePlatformAdmin(
  req: AuthenticatedRequest,
  _res: Response,
  next: NextFunction
): void {
  if (!req.user || !req.user.isPlatformAdmin) {
    logger.warn(
      { event: 'ACCESS_DENIED', reason: 'NOT_PLATFORM_ADMIN', userId: req.user?.id, path: req.originalUrl },
      'Security Event: Platform admin access denied'
    );
    return next(new ForbiddenError('Platform administrator access required'));
  }
  next();
}

export function requireIdirRole(allowedRoles: MembershipRole[]) {
  return async (
    req: AuthenticatedRequest,
    _res: Response,
    next: NextFunction
  ): Promise<void> => {
    if (!req.user) {
      return next(new ForbiddenError('Authentication required'));
    }

    const idirId = req.params.idirId || req.body.idirId || (req.query.idirId as string);

    if (!idirId) {
      return next(new NotFoundError('Idir context (idirId) is required for this operation'));
    }

    // Platform admins have full access across Idirs
    if (req.user.isPlatformAdmin) {
      return next();
    }

    const membership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId: req.user.id,
        },
      },
      select: {
        id: true,
        idirId: true,
        role: true,
        memberNumber: true,
        status: true,
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      logger.warn(
        { event: 'ACCESS_DENIED', reason: 'INACTIVE_OR_NON_MEMBER', userId: req.user.id, idirId, path: req.originalUrl },
        'Security Event: User is not an active member of the requested Idir'
      );
      return next(
        new ForbiddenError('You are not an active member of this Idir')
      );
    }

    if (!allowedRoles.includes(membership.role)) {
      logger.warn(
        {
          event: 'ACCESS_DENIED',
          reason: 'INSUFFICIENT_ROLE',
          userId: req.user.id,
          idirId,
          currentRole: membership.role,
          requiredRoles: allowedRoles,
          path: req.originalUrl,
        },
        'Security Event: Access denied due to insufficient role permissions'
      );
      return next(
        new ForbiddenError(
          `Insufficient permissions: Required role [${allowedRoles.join(', ')}], current role is [${membership.role}]`
        )
      );
    }

    req.membership = {
      id: membership.id,
      idirId: membership.idirId,
      role: membership.role,
      memberNumber: membership.memberNumber,
    };

    next();
  };
}
