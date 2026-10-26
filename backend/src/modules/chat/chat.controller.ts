import { Response, NextFunction } from 'express';
import { chatService } from './chat.service.js';
import { sendSuccess, sendCreated } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';

export class ChatController {
  async getMessages(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { idirId } = req.params;
      const userId = req.user!.id;
      const query = req.query as any;

      const messages = await chatService.listMessages(idirId, userId, query);
      return sendSuccess(res, messages, 200, 'Chat messages retrieved successfully');
    } catch (error) {
      next(error);
    }
  }

  async sendMessage(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { idirId } = req.params;
      const userId = req.user!.id;
      const input = req.body;

      const message = await chatService.sendMessage(idirId, userId, input);
      return sendCreated(res, message, 'Message sent successfully');
    } catch (error) {
      next(error);
    }
  }
}

export const chatController = new ChatController();
