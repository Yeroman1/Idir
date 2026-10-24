import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../shared/types/index.js';
import { ForbiddenError } from '../../shared/errors/AppError.js';
import { sendCreated } from '../../shared/utils/response.js';
import { createDraftIdirService } from './create-draft.service.js';

export class CreateDraftIdirController {
  async handle(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      // Must be logged in (guaranteed by authenticate middleware)
      if (!req.user) {
        throw new ForbiddenError('Authentication is required to create an Idir');
      }

      const idir = await createDraftIdirService.createDraft(req.user!.id, req.body);
      return sendCreated(res, idir, 'Draft Idir created successfully');
    } catch (error) {
      next(error);
    }
  }
}

export const createDraftIdirController = new CreateDraftIdirController();
