import { z } from 'zod';

export const electableRoles = [
  'CHAIRPERSON',
  'TREASURER',
  'SECRETARY',
  'AUDITOR',
  'COMMITTEE',
  'OFFICER',
] as const;

export const createElectionSchema = z
  .object({
    title: z
      .string({ required_error: 'Election title is required' })
      .min(3, 'Election title must be at least 3 characters')
      .max(150, 'Election title must not exceed 150 characters'),
    description: z
      .string()
      .max(1000, 'Description must not exceed 1000 characters')
      .optional(),
    roles: z
      .array(z.enum(electableRoles, {
        invalid_type_error:
          'Contested role must be one of: CHAIRPERSON, TREASURER, SECRETARY, AUDITOR, COMMITTEE, OFFICER',
      }), { required_error: 'At least one leadership role must be contested' })
      .min(1, 'At least one leadership role must be contested')
      .refine((items) => new Set(items).size === items.length, {
        message: 'Duplicate roles cannot be specified in the same election',
      }),
    startDate: z.coerce.date({
      required_error: 'Election voting start date is required',
      invalid_type_error: 'Invalid start date format',
    }),
    endDate: z.coerce.date({
      required_error: 'Election voting end date is required',
      invalid_type_error: 'Invalid end date format',
    }),
    nominationStartDate: z.coerce.date().optional(),
    nominationEndDate: z.coerce.date().optional(),
    termLengthMonths: z.coerce
      .number({ required_error: 'Term length is required' })
      .int('Term length in months must be an integer')
      .min(1, 'Term length must be at least 1 month')
      .max(120, 'Term length cannot exceed 120 months (10 years)'),
    votingMethod: z.enum(['SIMPLE_MAJORITY', 'RUNOFF'], {
      required_error: 'Voting method is required',
      invalid_type_error: 'Voting method must be SIMPLE_MAJORITY or RUNOFF',
    }),
    ballotType: z.enum(['SECRET', 'OPEN'], {
      required_error: 'Ballot type is required',
      invalid_type_error: 'Ballot type must be SECRET or OPEN',
    }),
    quorumPercentage: z.coerce
      .number({ required_error: 'Quorum percentage is required' })
      .min(1, 'Quorum percentage must be at least 1%')
      .max(100, 'Quorum percentage cannot exceed 100%'),
    minMembershipTenureDays: z.coerce
      .number()
      .int('Tenure days must be an integer')
      .min(0, 'Tenure days cannot be negative')
      .default(0),
    requiresGoodStanding: z.boolean().default(true),
    disputeWindowHours: z.coerce
      .number()
      .int('Dispute window hours must be an integer')
      .min(1, 'Dispute window must be at least 1 hour')
      .max(720, 'Dispute window cannot exceed 720 hours (30 days)')
      .default(48),
    handoverDate: z.coerce.date().optional(),
    committeeMemberIds: z
      .array(z.string().min(1, 'Committee member ID must not be empty'), {
        required_error: 'Election committee members are required',
      })
      .min(1, 'At least one neutral election committee member must be assigned')
      .refine((ids) => new Set(ids).size === ids.length, {
        message: 'Duplicate committee members cannot be assigned',
      }),
  })
  .superRefine((data, ctx) => {
    // 1. Voting endDate must be after startDate
    if (data.endDate <= data.startDate) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['endDate'],
        message: 'Election end date must be strictly after start date',
      });
    }

    // 2. Nomination period checks
    if (data.nominationStartDate && data.nominationEndDate) {
      if (data.nominationEndDate <= data.nominationStartDate) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['nominationEndDate'],
          message: 'Nomination end date must be after nomination start date',
        });
      }
    }

    if (data.nominationEndDate && data.startDate) {
      if (data.nominationEndDate > data.startDate) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['nominationEndDate'],
          message: 'Nomination period must conclude on or before voting start date',
        });
      }
    }

    // 3. Handover date must be on or after voting endDate
    if (data.handoverDate && data.endDate) {
      if (data.handoverDate < data.endDate) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['handoverDate'],
          message: 'Leadership handover date cannot precede election end date',
        });
      }
    }
  });

export const updateElectionSchema = z
  .object({
    title: z.string().min(3).max(150).optional(),
    description: z.string().max(1000).optional(),
    roles: z
      .array(z.enum(electableRoles))
      .min(1)
      .refine((items) => new Set(items).size === items.length, {
        message: 'Duplicate roles cannot be specified',
      })
      .optional(),
    startDate: z.coerce.date().optional(),
    endDate: z.coerce.date().optional(),
    termLengthMonths: z.coerce.number().int().min(1).max(120).optional(),
    votingMethod: z.enum(['SIMPLE_MAJORITY', 'RUNOFF']).optional(),
    ballotType: z.enum(['SECRET', 'OPEN']).optional(),
    quorumPercentage: z.coerce.number().min(1).max(100).optional(),
    minMembershipTenureDays: z.coerce.number().int().min(0).optional(),
    requiresGoodStanding: z.boolean().optional(),
    disputeWindowHours: z.coerce.number().int().min(1).max(720).optional(),
    handoverDate: z.coerce.date().optional(),
    committeeMemberIds: z
      .array(z.string().min(1))
      .min(1)
      .refine((ids) => new Set(ids).size === ids.length, {
        message: 'Duplicate committee members cannot be assigned',
      })
      .optional(),
  })
  .superRefine((data, ctx) => {
    if (data.startDate && data.endDate && data.endDate <= data.startDate) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['endDate'],
        message: 'Election end date must be strictly after start date',
      });
    }
  });

export const queryElectionsSchema = z.object({
  status: z
    .enum([
      'DRAFT',
      'NOMINATING',
      'VOTING',
      'TALLYING',
      'DISPUTED',
      'COMPLETED',
      'CANCELLED',
    ])
    .optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export const cancelElectionSchema = z.object({
  reason: z
    .string({ required_error: 'Cancellation reason is required' })
    .min(5, 'Cancellation reason must be at least 5 characters')
    .max(500, 'Cancellation reason must not exceed 500 characters'),
});

export type CreateElectionInput = z.infer<typeof createElectionSchema>;
export type UpdateElectionInput = z.infer<typeof updateElectionSchema>;
export type QueryElectionsInput = z.infer<typeof queryElectionsSchema>;
export type CancelElectionInput = z.infer<typeof cancelElectionSchema>;
