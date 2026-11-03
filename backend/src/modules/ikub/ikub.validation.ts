import { z } from 'zod';

export const createIkubGroupSchema = z.object({
  name: z.string().min(2, 'Ikub group name must be at least 2 characters'),
  description: z.string().optional(),
  contributionAmount: z.coerce.number().positive('Contribution amount must be greater than zero'),
  frequency: z.enum(['WEEKLY', 'BIWEEKLY', 'MONTHLY']).default('WEEKLY'),
  startDate: z.string().datetime().or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)),
  totalRounds: z.coerce.number().int().positive().default(10),
  payoutRule: z.enum(['LOTTERY', 'FIXED_ORDER', 'NEED_BASED']).default('LOTTERY'),
  winnersPerRound: z.coerce.number().int().positive().default(1),
  drawMode: z.enum(['DIGITAL_LOTTERY', 'PHYSICAL_RECORDED', 'NEED_BASED']).default('DIGITAL_LOTTERY'),
});

export const drawLotterySchema = z.object({
  manualWinnerId: z.string().uuid('Valid manual winner participantId is required').optional(),
  note: z.string().optional(),
});

export const createJoinRequestSchema = z.object({
  note: z.string().optional(),
});

export const respondJoinRequestSchema = z.object({
  status: z.enum(['APPROVED', 'REJECTED']),
});

export const addParticipantSchema = z.object({
  membershipId: z.string().uuid('Valid membershipId is required'),
  payoutOrder: z.coerce.number().int().positive().optional(),
});

export const createRoundSchema = z.object({
  roundNumber: z.coerce.number().int().positive('Round number must be positive'),
  scheduledDate: z.string().datetime().or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)),
  recipientParticipantId: z.string().uuid().optional(),
});

export const recordIkubContributionSchema = z.object({
  roundId: z.string().uuid('Valid roundId is required'),
  participantId: z.string().uuid('Valid participantId is required'),
  amount: z.coerce.number().positive('Contribution amount must be positive'),
  paymentMethod: z
    .enum(['CASH', 'BANK_TRANSFER', 'TELEBIRR', 'CBE_BIRR', 'OTHER'])
    .default('CASH'),
  paymentReference: z.string().optional(),
  clientMutationId: z.string().uuid().optional(),
});

export const recordIkubPayoutSchema = z.object({
  roundId: z.string().uuid('Valid roundId is required'),
  recipientParticipantId: z.string().uuid('Valid recipientParticipantId is required'),
  amount: z.coerce.number().positive('Payout amount must be positive'),
  paymentMethod: z
    .enum(['CASH', 'BANK_TRANSFER', 'TELEBIRR', 'CBE_BIRR', 'OTHER'])
    .default('CASH'),
  paymentReference: z.string().optional(),
});

export const queryIkubGroupsSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
  status: z.enum(['DRAFT', 'ACTIVE', 'COMPLETED', 'CANCELLED']).optional(),
});

export type CreateIkubGroupInput = z.infer<typeof createIkubGroupSchema>;
export type AddParticipantInput = z.infer<typeof addParticipantSchema>;
export type CreateRoundInput = z.infer<typeof createRoundSchema>;
export type RecordIkubContributionInput = z.infer<typeof recordIkubContributionSchema>;
export type RecordIkubPayoutInput = z.infer<typeof recordIkubPayoutSchema>;
export type DrawLotteryInput = z.infer<typeof drawLotterySchema>;
export type CreateJoinRequestInput = z.infer<typeof createJoinRequestSchema>;
export type RespondJoinRequestInput = z.infer<typeof respondJoinRequestSchema>;
