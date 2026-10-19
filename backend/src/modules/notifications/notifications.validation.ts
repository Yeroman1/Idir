import { z } from 'zod';

export const createAnnouncementSchema = z.object({
  title: z.string().min(2, 'Announcement title is required'),
  body: z.string().min(5, 'Announcement body must be at least 5 characters'),
  priority: z.enum(['NORMAL', 'URGENT']).default('NORMAL'),
  target: z.enum(['ALL', 'COMMITTEE', 'MEMBERS']).default('ALL'),
  isPinned: z.boolean().default(false),
});

export type CreateAnnouncementInput = z.infer<typeof createAnnouncementSchema>;
