import { Response, NextFunction } from 'express';
import { contributionsService } from './contributions.service.js';
import { sendSuccess, sendCreated } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';

export class ContributionsController {
  async createType(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const type = await contributionsService.createType(
        req.params.idirId,
        req.body,
        req.user!.id
      );
      return sendCreated(res, type, 'Contribution type created successfully');
    } catch (error) {
      next(error);
    }
  }

  async listTypes(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const types = await contributionsService.listTypes(req.params.idirId);
      return sendSuccess(res, types);
    } catch (error) {
      next(error);
    }
  }

  async recordContribution(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const contribution = await contributionsService.recordContribution(
        req.params.idirId,
        req.body,
        req.user!.id
      );
      return sendCreated(res, contribution, 'Contribution recorded successfully');
    } catch (error) {
      next(error);
    }
  }

  async confirmContribution(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const contribution = await contributionsService.confirmContribution(
        req.params.idirId,
        req.params.contributionId,
        req.user!.id
      );
      return sendSuccess(res, contribution, 200, 'Contribution confirmed');
    } catch (error) {
      next(error);
    }
  }

  async reverseContribution(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const contribution = await contributionsService.reverseContribution(
        req.params.idirId,
        req.params.contributionId,
        req.body,
        req.user!.id
      );
      return sendSuccess(res, contribution, 200, 'Contribution reversed successfully');
    } catch (error) {
      next(error);
    }
  }

  async listContributions(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { page, limit, membershipId, contributionTypeId, status, startDate, endDate } =
        req.query;
      const result = await contributionsService.listContributions(req.params.idirId, {
        page: page ? Number(page) : undefined,
        limit: limit ? Number(limit) : undefined,
        membershipId: membershipId as string,
        contributionTypeId: contributionTypeId as string,
        status: status as any,
        startDate: startDate as string,
        endDate: endDate as string,
      });
      return sendSuccess(res, result.items, 200, undefined, result.meta);
    } catch (error) {
      next(error);
    }
  }

  async getContributionById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const contribution = await contributionsService.getContributionById(
        req.params.idirId,
        req.params.contributionId
      );
      return sendSuccess(res, contribution);
    } catch (error) {
      next(error);
    }
  }
}

export const contributionsController = new ContributionsController();
