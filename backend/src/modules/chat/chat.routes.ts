import { Router } from 'express';
import { chatController } from './chat.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireActiveIdir } from '../../middleware/assertIdirActive.js';
import { validate } from '../../middleware/validate.js';
import {
  sendChatMessageSchema,
  queryChatMessagesSchema,
} from './chat.validation.js';

const router = Router({ mergeParams: true });

// All chat routes require an authenticated user and an active Idir association
router.use(authenticate);
router.use(requireActiveIdir());

// Retrieve chat history
router.get(
  '/',
  validate({ query: queryChatMessagesSchema }),
  chatController.getMessages
);

// Send message to group chat
router.post(
  '/',
  validate({ body: sendChatMessageSchema }),
  chatController.sendMessage
);

export const chatRoutes = router;
