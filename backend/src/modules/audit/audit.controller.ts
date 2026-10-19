import { Response, NextFunction } from 'express';
import { auditService } from './audit.service.js';
import { sendSuccess } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';

export class AuditController {
  async listLogs(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { page, limit, action, entityType, actorId } = req.query;
      const result = await auditService.listLogs(req.params.idirId, {
        page: page ? Number(page) : undefined,
        limit: limit ? Number(limit) : undefined,
        action: action as string,
        entityType: entityType as string,
        actorId: actorId as string,
      });
      return sendSuccess(res, result.items, 200, undefined, result.meta);
    } catch (error) {
      next(error);
    }
  }
}

export const auditController = new AuditController();
