import { z } from 'zod';

export const sendChatMessageSchema = z
  .object({
    content: z.string().trim().max(5000, 'Message cannot exceed 5000 characters').optional().default(''),
    messageType: z
      .enum([
        'TEXT',
        'IMAGE',
        'VIDEO',
        'AUDIO',
        'VOICE',
        'DOCUMENT',
        'PDF',
        'ANNOUNCEMENT',
        'EMERGENCY',
        'CONTRIBUTION_REMINDER',
      ])
      .default('TEXT'),
    replyToId: z.string().uuid().optional().nullable().or(z.string().optional().nullable()),
    replyToSenderName: z.string().max(100).optional().nullable(),
    replyToContent: z.string().max(500).optional().nullable(),
    isForwarded: z.boolean().optional().default(false),
    forwardedFromName: z.string().max(100).optional().nullable(),
    attachmentUrl: z.string().url().optional().nullable().or(z.string().optional().nullable()),
    attachmentType: z
      .enum(['IMAGE', 'VIDEO', 'AUDIO', 'VOICE', 'DOCUMENT', 'PDF'])
      .optional()
      .nullable(),
    attachmentName: z.string().max(255).optional().nullable(),
    attachmentSize: z.number().int().nonnegative().optional().nullable(),
    attachmentDuration: z.number().int().nonnegative().optional().nullable(),
    clientMutationId: z.string().max(128).optional().nullable(),
    mentions: z.array(z.string()).optional().nullable(),
  })
  .refine(
    (data) => {
      // Must have either non-empty content or an attachment
      return data.content.trim().length > 0 || (data.attachmentUrl && data.attachmentUrl.length > 0);
    },
    { message: 'Message must have text content or an attachment', path: ['content'] }
  );

export const updateChatMessageSchema = z.object({
  content: z
    .string()
    .trim()
    .min(1, 'Message cannot be empty')
    .max(5000, 'Message cannot exceed 5000 characters'),
});

export const queryChatMessagesSchema = z.object({
  limit: z.coerce.number().min(1).max(100).default(50),
  before: z.string().datetime().optional(),
  after: z.string().datetime().optional(),
  search: z.string().trim().optional(),
  pinnedOnly: z
    .string()
    .optional()
    .transform((val) => val === 'true'),
});

export const pinChatMessageSchema = z.object({
  isPinned: z.boolean(),
});

export const reactChatMessageSchema = z.object({
  emoji: z.string().trim().min(1).max(10),
  action: z.enum(['add', 'remove']).default('add'),
});

export const uploadChatAttachmentSchema = z.object({
  fileName: z.string().min(1).max(255),
  fileType: z.string().min(1).max(100),
  fileSize: z.number().int().positive().max(30 * 1024 * 1024, 'File exceeds 30MB limit'),
  base64Data: z.string().min(1, 'File data cannot be empty'),
  duration: z.number().int().nonnegative().optional(),
});

export const reportChatMessageSchema = z.object({
  reason: z.string().trim().min(2, 'Please provide a reason').max(500),
});

export type SendChatMessageInput = z.infer<typeof sendChatMessageSchema>;
export type UpdateChatMessageInput = z.infer<typeof updateChatMessageSchema>;
export type QueryChatMessagesInput = z.infer<typeof queryChatMessagesSchema>;
export type PinChatMessageInput = z.infer<typeof pinChatMessageSchema>;
export type ReactChatMessageInput = z.infer<typeof reactChatMessageSchema>;
export type UploadChatAttachmentInput = z.infer<typeof uploadChatAttachmentSchema>;
export type ReportChatMessageInput = z.infer<typeof reportChatMessageSchema>;
