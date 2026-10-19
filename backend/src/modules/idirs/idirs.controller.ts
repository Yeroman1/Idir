import { Response, NextFunction } from 'express';
import { idirsService } from './idirs.service.js';
import { sendSuccess, sendCreated } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';

export class IdirsController {
  async createIdir(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const idir = await idirsService.createIdir(req.user!.id, req.body);
      return sendCreated(res, idir, 'Idir created successfully');
    } catch (error) {
      next(error);
    }
  }

  async listIdirs(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { page, limit, search, region } = req.query;
      const result = await idirsService.listIdirs({
        page: page ? Number(page) : undefined,
        limit: limit ? Number(limit) : undefined,
        search: search as string,
        region: region as string,
        userId: req.user!.isPlatformAdmin ? undefined : req.user!.id,
      });
      return sendSuccess(res, result.items, 200, undefined, result.meta);
    } catch (error) {
      next(error);
    }
  }

  async getIdirById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const idir = await idirsService.getIdirById(req.params.idirId);
      return sendSuccess(res, idir);
    } catch (error) {
      next(error);
    }
  }

  async updateIdir(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const idir = await idirsService.updateIdir(req.params.idirId, req.body, req.user!.id);
      return sendSuccess(res, idir, 200, 'Idir updated successfully');
    } catch (error) {
      next(error);
    }
  }

  async updateSettings(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const settings = await idirsService.updateSettings(
        req.params.idirId,
        req.body,
        req.user!.id
      );
      return sendSuccess(res, settings, 200, 'Settings updated successfully');
    } catch (error) {
      next(error);
    }
  }
}

export const idirsController = new IdirsController();
