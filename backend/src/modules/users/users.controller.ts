import { Response, NextFunction } from 'express';
import { usersService } from './users.service.js';
import { sendSuccess } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';
import { ForbiddenError } from '../../shared/errors/AppError.js';

export class UsersController {
  async getMe(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const user = await usersService.getProfile(req.user!.id);
      return sendSuccess(res, user);
    } catch (error) {
      next(error);
    }
  }

  async updateMe(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const user = await usersService.updateProfile(req.user!.id, req.body);
      return sendSuccess(res, user, 200, 'Profile updated successfully');
    } catch (error) {
      next(error);
    }
  }

  async getUserById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const targetId = req.params.userId === 'me' ? req.user!.id : req.params.userId;
      if (targetId !== req.user!.id && !req.user!.isPlatformAdmin) {
        throw new ForbiddenError('You can only access your own profile');
      }
      const user = await usersService.getProfile(targetId);
      return sendSuccess(res, user);
    } catch (error) {
      next(error);
    }
  }

  async updateUserById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const targetId = req.params.userId === 'me' ? req.user!.id : req.params.userId;
      if (targetId !== req.user!.id && !req.user!.isPlatformAdmin) {
        throw new ForbiddenError('You can only update your own profile');
      }
      const user = await usersService.updateProfile(targetId, req.body);
      return sendSuccess(res, user, 200, 'Profile updated successfully');
    } catch (error) {
      next(error);
    }
  }
}

export const usersController = new UsersController();
