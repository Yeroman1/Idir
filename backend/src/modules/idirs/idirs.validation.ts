import { z } from 'zod';

export const createIdirSchema = z.object({
  name: z.string().min(2, 'Idir name must be at least 2 characters'),
  description: z.string().optional(),
  region: z.string().min(2, 'Region is required (e.g. Addis Ababa, Oromia, Amhara)'),
  zone: z.string().optional(),
  woreda: z.string().optional(),
  kebele: z.string().optional(),
  address: z.string().optional(),
  contactPhone: z.string().optional(),
  contactEmail: z.string().email().optional(),
  currency: z.string().default('ETB'),
});

export const updateIdirSchema = createIdirSchema.partial();

export const updateSettingsSchema = z.object({
  regularDuesAmount: z.coerce.number().positive('Regular dues must be greater than zero').optional(),
  duesFrequency: z.enum(['WEEKLY', 'BIWEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUALLY']).optional(),
  latePaymentGraceDays: z.coerce.number().int().nonnegative().optional(),
  meetingFrequency: z.enum(['WEEKLY', 'BIWEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUALLY']).optional(),
  allowIkub: z.boolean().optional(),
  maxAssistancePerYear: z.coerce.number().positive().optional().nullable(),
  requireMultiApproval: z.boolean().optional(),
});

export const queryIdirsSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
  search: z.string().optional(),
  region: z.string().optional(),
});

export type CreateIdirInput = z.infer<typeof createIdirSchema>;
export type UpdateIdirInput = z.infer<typeof updateIdirSchema>;
export type UpdateSettingsInput = z.infer<typeof updateSettingsSchema>;
