import { z } from 'zod';

export const createCaseSchema = z.object({
  membershipId: z.string().uuid('Valid membershipId is required'),
  caseType: z
    .enum(['FUNERAL', 'ILLNESS', 'ACCIDENT', 'PROPERTY_LOSS', 'OTHER'])
    .default('FUNERAL'),
  title: z.string().min(3, 'Title is required'),
  description: z.string().min(5, 'Detailed description is required'),
  deceasedName: z.string().optional(),
  deceasedRelation: z.string().optional(),
  isConfidential: z.boolean().default(false),
});

export const submitRequestSchema = z.object({
  requestedAmount: z.coerce.number().positive('Requested amount must be greater than zero'),
  justification: z.string().min(5, 'Justification is required'),
});

export const reviewRequestSchema = z.object({
  approved: z.boolean(),
  reviewNotes: z.string().optional(),
});

export const disburseSchema = z.object({
  amount: z.coerce.number().positive('Disbursement amount must be greater than zero'),
  recipientName: z.string().min(2, 'Recipient name is required'),
  recipientPhone: z.string().optional(),
  paymentMethod: z
    .enum(['CASH', 'BANK_TRANSFER', 'TELEBIRR', 'CBE_BIRR', 'OTHER'])
    .default('CASH'),
  paymentReference: z.string().optional(),
});

export const queryCasesSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
  membershipId: z.string().uuid().optional(),
  caseType: z
    .enum(['FUNERAL', 'ILLNESS', 'ACCIDENT', 'PROPERTY_LOSS', 'OTHER'])
    .optional(),
  status: z.enum(['OPEN', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'CLOSED']).optional(),
});

export type CreateCaseInput = z.infer<typeof createCaseSchema>;
export type SubmitRequestInput = z.infer<typeof submitRequestSchema>;
export type ReviewRequestInput = z.infer<typeof reviewRequestSchema>;
export type DisburseInput = z.infer<typeof disburseSchema>;
