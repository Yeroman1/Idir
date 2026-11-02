import { Router } from 'express';
import { chatController } from './chat.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireActiveIdir } from '../../middleware/assertIdirActive.js';
import { validate } from '../../middleware/validate.js';
import {
  sendChatMessageSchema,
  updateChatMessageSchema,
  queryChatMessagesSchema,
  pinChatMessageSchema,
  reactChatMessageSchema,
  uploadChatAttachmentSchema,
  reportChatMessageSchema,
} from './chat.validation.js';

const router = Router({ mergeParams: true });

// All chat routes require an authenticated user and an active Idir association
router.use(authenticate);
router.use(requireActiveIdir());

// Retrieve chat history (with pagination & search support)
router.get(
  '/',
  validate({ query: queryChatMessagesSchema }),
  chatController.getMessages
);

// Retrieve pinned messages
router.get(
  '/pinned',
  chatController.getPinnedMessages
);

// Upload attachment (images, videos, voice/audio notes, pdf/docs)
router.post(
  '/upload',
  validate({ body: uploadChatAttachmentSchema }),
  chatController.uploadAttachment
);

// Send message to group chat (text, attachment, announcement, reply, forward)
router.post(
  '/',
  validate({ body: sendChatMessageSchema }),
  chatController.sendMessage
);

// Edit own message
router.patch(
  '/:messageId',
  validate({ body: updateChatMessageSchema }),
  chatController.editMessage
);

// Delete message (sender can delete own; admin can delete any)
router.delete(
  '/:messageId',
  chatController.deleteMessage
);

// Pin / Unpin message (leadership only)
router.post(
  '/:messageId/pin',
  validate({ body: pinChatMessageSchema }),
  chatController.pinMessage
);

// React / Unreact with emoji
router.post(
  '/:messageId/react',
  validate({ body: reactChatMessageSchema }),
  chatController.reactToMessage
);

// Report message for moderation
router.post(
  '/:messageId/report',
  validate({ body: reportChatMessageSchema }),
  chatController.reportMessage
);

export const chatRoutes = router;
