import { z } from 'zod';
import { MembershipRole } from '@prisma/client';

export const initiateNoConfidenceSchema = z.object({
  targetMembershipId: z.string().uuid('Invalid target member ID'),
  targetRole: z.nativeEnum(MembershipRole),
  reason: z.string().trim().min(10, 'Grounds for no-confidence motion must be at least 10 characters'),
  thresholdPercentage: z.number().min(50).max(100).default(66.67),
  quorumPercentage: z.number().min(1).max(100).default(50.0),
  durationDays: z.number().int().min(1).max(30).default(7),
});

export const castNoConfidenceVoteSchema = z.object({
  choice: z.enum(['SUPPORT', 'OPPOSE']),
});

export const resolveNoConfidenceSchema = z.object({
  force: z.boolean().default(false),
});

export const appointInterimSchema = z.object({
  vacantRole: z.nativeEnum(MembershipRole),
  appointeeMembershipId: z.string().uuid('Invalid appointee member ID'),
  reason: z.string().trim().optional(),
  termMonths: z.number().int().min(1).max(12).default(6),
});

export const createByElectionSchema = z.object({
  vacantRole: z.nativeEnum(MembershipRole),
  title: z.string().trim().min(3).optional(),
  description: z.string().trim().optional(),
  startDate: z.string().datetime(),
  endDate: z.string().datetime(),
  nominationStartDate: z.string().datetime().optional(),
  nominationEndDate: z.string().datetime().optional(),
  termLengthMonths: z.number().int().min(1).max(120).default(12),
  votingMethod: z.enum(['SIMPLE_MAJORITY', 'RUNOFF']).default('SIMPLE_MAJORITY'),
  ballotType: z.enum(['SECRET', 'OPEN']).default('SECRET'),
  quorumPercentage: z.number().min(1).max(100).default(50.0),
  committeeMemberIds: z.array(z.string().uuid()).min(1, 'At least one neutral committee member required'),
});

export type InitiateNoConfidenceInput = z.infer<typeof initiateNoConfidenceSchema>;
export type CastNoConfidenceVoteInput = z.infer<typeof castNoConfidenceVoteSchema>;
export type ResolveNoConfidenceInput = z.infer<typeof resolveNoConfidenceSchema>;
export type AppointInterimInput = z.infer<typeof appointInterimSchema>;
export type CreateByElectionInput = z.infer<typeof createByElectionSchema>;
