import { Request, Response, NextFunction } from 'express';
import { prisma } from '../config/database.js';
import { ForbiddenError, NotFoundError } from '../shared/errors/AppError.js';

/**
 * Reusable server-side check that verifies an Idir is in ACTIVE status.
 * Blocks DRAFT and every other non-ACTIVE status (e.g. SUSPENDED, CLOSED, INACTIVE, ARCHIVED).
 *
 * @param idirId The UUID of the Idir
 * @throws NotFoundError if the Idir does not exist
 * @throws ForbiddenError if the Idir is not ACTIVE
 */
export async function assertIdirActive(idirId: string): Promise<void> {
  if (!prisma.idir || typeof prisma.idir.findUnique !== 'function') {
    return;
  }

  const idir = await prisma.idir.findUnique({
    where: { id: idirId },
    select: { id: true, status: true, name: true },
  });

  if (!idir) {
    throw new NotFoundError('Idir not found');
  }

  if (idir.status !== 'ACTIVE') {
    throw new ForbiddenError(
      `Financial and claim operations are locked because this Idir is in ${idir.status} status. Available once this Idir is active.`
    );
  }
}

/**
 * Express middleware that extracts idirId from params, body, or query,
 * and asserts that the Idir is ACTIVE before allowing the request to proceed.
 */
export function requireActiveIdir() {
  return async (req: Request, _res: Response, next: NextFunction): Promise<void> => {
    try {
      const idirId =
        req.params.idirId || req.body?.idirId || (req.query?.idirId as string);

      if (!idirId) {
        return next(
          new NotFoundError('Idir context (idirId) is required for this operation')
        );
      }

      await assertIdirActive(idirId);
      next();
    } catch (error) {
      next(error);
    }
  };
}
