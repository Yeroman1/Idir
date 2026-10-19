import { Response, NextFunction } from 'express';
import { ikubService } from './ikub.service.js';
import { sendSuccess, sendCreated } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';

export class IkubController {
  async createGroup(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const group = await ikubService.createGroup(req.params.idirId, req.body, req.user!.id);
      return sendCreated(res, group, 'Ikub group created successfully');
    } catch (error) {
      next(error);
    }
  }

  async listGroups(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { page, limit, status } = req.query;
      const result = await ikubService.listGroups(req.params.idirId, {
        page: page ? Number(page) : undefined,
        limit: limit ? Number(limit) : undefined,
        status: status as any,
      });
      return sendSuccess(res, result.items, 200, undefined, result.meta);
    } catch (error) {
      next(error);
    }
  }

  async getGroupById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const group = await ikubService.getGroupById(req.params.idirId, req.params.groupId);
      return sendSuccess(res, group);
    } catch (error) {
      next(error);
    }
  }

  async addParticipant(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const participant = await ikubService.addParticipant(
        req.params.idirId,
        req.params.groupId,
        req.body,
        req.user!.id
      );
      return sendCreated(res, participant, 'Participant added to Ikub group');
    } catch (error) {
      next(error);
    }
  }

  async createRound(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const round = await ikubService.createRound(
        req.params.idirId,
        req.params.groupId,
        req.body,
        req.user!.id
      );
      return sendCreated(res, round, 'Ikub round created successfully');
    } catch (error) {
      next(error);
    }
  }

  async recordContribution(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const contribution = await ikubService.recordContribution(
        req.params.idirId,
        req.params.groupId,
        req.body,
        req.user!.id
      );
      return sendCreated(res, contribution, 'Ikub contribution recorded');
    } catch (error) {
      next(error);
    }
  }

  async recordPayout(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const payout = await ikubService.recordPayout(
        req.params.idirId,
        req.params.groupId,
        req.body,
        req.user!.id
      );
      return sendCreated(res, payout, 'Ikub round payout recorded successfully');
    } catch (error) {
      next(error);
    }
  }

  async getGroupSummary(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const summary = await ikubService.getGroupSummary(
        req.params.idirId,
        req.params.groupId
      );
      return sendSuccess(res, summary);
    } catch (error) {
      next(error);
    }
  }
}

export const ikubController = new IkubController();
