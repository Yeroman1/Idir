import { z } from 'zod';

export const createAnnouncementSchema = z.object({
  title: z.string().min(2, 'Announcement title is required'),
  body: z.string().min(5, 'Announcement body must be at least 5 characters'),
  priority: z.enum(['NORMAL', 'URGENT']).default('NORMAL'),
  target: z.enum(['ALL', 'COMMITTEE', 'MEMBERS']).default('ALL'),
  isPinned: z.boolean().default(false),
});

export type CreateAnnouncementInput = z.infer<typeof createAnnouncementSchema>;

export const updatePreferencesSchema = z.object({
  inAppEnabled: z.boolean().optional(),
  pushEnabled: z.boolean().optional(),
  smsEnabled: z.boolean().optional(),
  emailEnabled: z.boolean().optional(),
  reminderMeetings: z.boolean().optional(),
  reminderContributions: z.boolean().optional(),
  notifyAnnouncements: z.boolean().optional(),
  notifyGovernance: z.boolean().optional(),
  notifyAssistance: z.boolean().optional(),
  quietHoursEnabled: z.boolean().optional(),
  quietHoursStart: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/, 'Invalid time format (HH:MM)').nullable().optional(),
  quietHoursEnd: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/, 'Invalid time format (HH:MM)').nullable().optional(),
});

export type UpdatePreferencesInput = z.infer<typeof updatePreferencesSchema>;

export const registerDeviceTokenSchema = z.object({
  token: z.string().min(10, 'Device push token is required'),
  platform: z.enum(['android', 'ios', 'web']).default('android'),
});

export type RegisterDeviceTokenInput = z.infer<typeof registerDeviceTokenSchema>;

export const unregisterDeviceTokenSchema = z.object({
  token: z.string().min(10, 'Device push token is required'),
});

export type UnregisterDeviceTokenInput = z.infer<typeof unregisterDeviceTokenSchema>;

export const dispatchRemindersSchema = z.object({
  type: z.enum(['ALL', 'MEETINGS', 'CONTRIBUTIONS']).default('ALL'),
  leadHours: z.number().int().min(1).max(720).default(24),
});

export type DispatchRemindersInput = z.infer<typeof dispatchRemindersSchema>;
