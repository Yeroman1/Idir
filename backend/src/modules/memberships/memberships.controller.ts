import { Response, NextFunction } from 'express';
import { membershipsService } from './memberships.service.js';
import { sendSuccess, sendCreated } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';

export class MembershipsController {
  async addMember(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const member = await membershipsService.addMember(
        req.params.idirId,
        req.body,
        req.user!.id
      );
      return sendCreated(res, member, 'Member added successfully');
    } catch (error) {
      next(error);
    }
  }

  async listMembers(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { page, limit, search, role, status } = req.query;
      const result = await membershipsService.listMembers(req.params.idirId, {
        page: page ? Number(page) : undefined,
        limit: limit ? Number(limit) : undefined,
        search: search as string,
        role: role as any,
        status: status as any,
      });
      return sendSuccess(res, result.items, 200, undefined, result.meta);
    } catch (error) {
      next(error);
    }
  }

  async getMemberById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const member = await membershipsService.getMemberById(
        req.params.idirId,
        req.params.membershipId
      );
      return sendSuccess(res, member);
    } catch (error) {
      next(error);
    }
  }

  async updateMember(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const member = await membershipsService.updateMember(
        req.params.idirId,
        req.params.membershipId,
        req.body,
        req.user!.id
      );
      return sendSuccess(res, member, 200, 'Member updated successfully');
    } catch (error) {
      next(error);
    }
  }

  async deactivateMember(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const member = await membershipsService.deactivateMember(
        req.params.idirId,
        req.params.membershipId,
        req.user!.id
      );
      return sendSuccess(res, member, 200, 'Member deactivated successfully');
    } catch (error) {
      next(error);
    }
  }
}

export const membershipsController = new MembershipsController();
