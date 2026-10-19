import { Response, NextFunction } from 'express';
import { usersService } from './users.service.js';
import { sendSuccess } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';

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
}

export const usersController = new UsersController();
