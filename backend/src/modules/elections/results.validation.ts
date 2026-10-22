import { z } from 'zod';
import { MembershipRole } from '@prisma/client';

export const tallyVotesSchema = z.object({
  force: z.boolean().optional().default(false),
});

export const fileDisputeSchema = z.object({
  reason: z
    .string({ required_error: 'Dispute reason is required' })
    .trim()
    .min(10, 'Dispute reason must be at least 10 characters')
    .max(2000, 'Dispute reason cannot exceed 2000 characters'),
});

export const resolveDisputeSchema = z.object({
  action: z.enum(['RESOLVE', 'DISMISS'], {
    required_error: 'Action must be either RESOLVE or DISMISS',
  }),
  resolution: z
    .string({ required_error: 'Resolution description is required' })
    .trim()
    .min(5, 'Resolution description must be at least 5 characters')
    .max(2000, 'Resolution description cannot exceed 2000 characters'),
});

export const certifyElectionSchema = z.object({
  notes: z.string().trim().max(1000).optional(),
});

export const triggerRunoffSchema = z.object({
  role: z.nativeEnum(MembershipRole, {
    required_error: 'Role is required for triggering a run-off',
  }),
  runoffEndDate: z.string().datetime().optional(),
});

export type TallyVotesInput = z.infer<typeof tallyVotesSchema>;
export type FileDisputeInput = z.infer<typeof fileDisputeSchema>;
export type ResolveDisputeInput = z.infer<typeof resolveDisputeSchema>;
export type CertifyElectionInput = z.infer<typeof certifyElectionSchema>;
export type TriggerRunoffInput = z.infer<typeof triggerRunoffSchema>;
