import { Response, NextFunction } from 'express';
import { reportsService } from './reports.service.js';
import { sendSuccess } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';
import { ForbiddenError } from '../../shared/errors/AppError.js';

export class ReportsController {
  async getIdirFinancialReport(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { startDate, endDate } = req.query;
      const report = await reportsService.getIdirFinancialReport(req.params.idirId, {
        startDate: startDate as string,
        endDate: endDate as string,
      });
      return sendSuccess(res, report);
    } catch (error) {
      next(error);
    }
  }

  async getMemberContributionReport(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ) {
    try {
      // BROKEN ACCESS CONTROL FIX (IDOR): Ordinary members can only view their own contribution report
      if (
        req.membership?.role === 'MEMBER' &&
        req.params.membershipId !== req.membership.id
      ) {
        throw new ForbiddenError(
          'You are not authorized to view another member\'s financial contribution report'
        );
      }

      const report = await reportsService.getMemberContributionReport(
        req.params.idirId,
        req.params.membershipId
      );
      return sendSuccess(res, report);
    } catch (error) {
      next(error);
    }
  }
}

export const reportsController = new ReportsController();
