import { z } from 'zod';

export const batchInviteSchema = z.object({
  phoneNumbers: z
    .array(z.string().min(1, 'Phone number item cannot be empty'))
    .min(1, 'At least one phone number is required')
    .max(50, 'Cannot invite more than 50 phone numbers in a single batch'),
  expiresInDays: z
    .number()
    .int('Expiration days must be an integer')
    .min(1, 'Expiration must be at least 1 day')
    .max(30, 'Expiration cannot exceed 30 days')
    .optional()
    .default(7),
});

export type BatchInviteInput = z.infer<typeof batchInviteSchema>;
