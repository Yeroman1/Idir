import { z } from 'zod';

export const createContributionTypeSchema = z.object({
  name: z.string().min(2, 'Contribution type name is required'),
  description: z.string().optional(),
  defaultAmount: z.coerce.number().positive('Default amount must be positive').optional(),
  isMandatory: z.boolean().default(true),
});

export const recordContributionSchema = z.object({
  membershipId: z.string().uuid('Valid membershipId is required'),
  contributionTypeId: z.string().uuid('Valid contributionTypeId is required'),
  amount: z.coerce.number().positive('Contribution amount must be greater than zero'),
  paymentDate: z.string().datetime().or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)).optional(),
  paymentMethod: z
    .enum(['CASH', 'BANK_TRANSFER', 'TELEBIRR', 'CBE_BIRR', 'OTHER'])
    .default('CASH'),
  paymentReference: z.string().optional(),
  notes: z.string().optional(),
  status: z.enum(['PENDING', 'CONFIRMED']).default('CONFIRMED'),
  clientMutationId: z.string().uuid().optional(), // Idempotency key for offline mobile sync
});

export const reverseContributionSchema = z.object({
  reversalReason: z.string().min(5, 'Reversal reason must be at least 5 characters'),
});

export const queryContributionsSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
  membershipId: z.string().uuid().optional(),
  contributionTypeId: z.string().uuid().optional(),
  status: z.enum(['PENDING', 'CONFIRMED', 'FAILED', 'REVERSED']).optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
});

export type CreateContributionTypeInput = z.infer<typeof createContributionTypeSchema>;
export type RecordContributionInput = z.infer<typeof recordContributionSchema>;
export type ReverseContributionInput = z.infer<typeof reverseContributionSchema>;
