import { z } from 'zod';
import { electableRoles } from './elections.validation.js';

export const castVoteSchema = z.object({
  role: z.enum(electableRoles, {
    required_error: 'Role is required for voting',
    invalid_type_error: 'Role must be an electable leadership position',
  }),
  candidateNominationId: z
    .string({ required_error: 'Candidate nomination ID is required' })
    .min(1, 'Candidate nomination ID cannot be empty'),
});

export const castBatchVotesSchema = z.object({
  votes: z
    .array(
      z.object({
        role: z.enum(electableRoles, {
          required_error: 'Role is required',
        }),
        candidateNominationId: z
          .string({ required_error: 'Candidate nomination ID is required' })
          .min(1, 'Candidate nomination ID cannot be empty'),
      })
    )
    .min(1, 'At least one vote selection must be provided')
    .max(10, 'Cannot cast more than 10 votes in a single submission'),
});

export type CastVoteInput = z.infer<typeof castVoteSchema>;
export type CastBatchVotesInput = z.infer<typeof castBatchVotesSchema>;
