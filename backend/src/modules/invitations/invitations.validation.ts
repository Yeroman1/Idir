import { z } from 'zod';

export const batchInviteSchema = z
  .object({
    phoneNumbers: z
      .array(z.string().min(1, 'Phone number item cannot be empty'))
      .max(50, 'Cannot invite more than 50 phone numbers in a single batch')
      .optional()
      .default([]),
    emails: z
      .array(z.string().email('Invalid email address format'))
      .max(50, 'Cannot invite more than 50 emails in a single batch')
      .optional()
      .default([]),
    expiresInDays: z
      .number()
      .int('Expiration days must be an integer')
      .min(1, 'Expiration must be at least 1 day')
      .max(30, 'Expiration cannot exceed 30 days')
      .optional()
      .default(7),
  })
  .refine(
    (data) =>
      (data.phoneNumbers && data.phoneNumbers.length > 0) ||
      (data.emails && data.emails.length > 0),
    {
      message: 'At least one phone number or email address is required',
    }
  );

export type BatchInviteInput = z.infer<typeof batchInviteSchema>;

