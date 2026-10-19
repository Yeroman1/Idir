import { Response, NextFunction } from 'express';
import { assistanceService } from './assistance.service.js';
import { sendSuccess, sendCreated } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';

export class AssistanceController {
  async createCase(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const assistanceCase = await assistanceService.createCase(
        req.params.idirId,
        req.body,
        req.user!.id
      );
      return sendCreated(res, assistanceCase, 'Assistance case opened successfully');
    } catch (error) {
      next(error);
    }
  }

  async listCases(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { page, limit, membershipId, caseType, status } = req.query;
      const result = await assistanceService.listCases(
        req.params.idirId,
        {
          page: page ? Number(page) : undefined,
          limit: limit ? Number(limit) : undefined,
          membershipId: membershipId as string,
          caseType: caseType as any,
          status: status as any,
        },
        {
          userId: req.user!.id,
          role: req.membership?.role,
          isPlatformAdmin: req.user!.isPlatformAdmin,
        }
      );
      return sendSuccess(res, result.items, 200, undefined, result.meta);
    } catch (error) {
      next(error);
    }
  }

  async getCaseById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const assistanceCase = await assistanceService.getCaseById(
        req.params.idirId,
        req.params.caseId,
        {
          userId: req.user!.id,
          role: req.membership?.role,
          isPlatformAdmin: req.user!.isPlatformAdmin,
        }
      );
      return sendSuccess(res, assistanceCase);
    } catch (error) {
      next(error);
    }
  }

  async submitRequest(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const request = await assistanceService.submitRequest(
        req.params.idirId,
        req.params.caseId,
        req.body,
        req.user!.id
      );
      return sendCreated(res, request, 'Assistance request submitted successfully');
    } catch (error) {
      next(error);
    }
  }

  async reviewRequest(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const request = await assistanceService.reviewRequest(
        req.params.idirId,
        req.params.caseId,
        req.params.requestId,
        req.body,
        req.user!.id
      );
      return sendSuccess(res, request, 200, `Request ${request.status.toLowerCase()}`);
    } catch (error) {
      next(error);
    }
  }

  async recordDisbursement(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const disbursement = await assistanceService.recordDisbursement(
        req.params.idirId,
        req.params.requestId,
        req.body,
        req.user!.id
      );
      return sendCreated(res, disbursement, 'Assistance funds disbursed successfully');
    } catch (error) {
      next(error);
    }
  }
}

export const assistanceController = new AssistanceController();
