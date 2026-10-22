import { z } from 'zod';
import { electableRoles } from './elections.validation.js';

export const createNominationSchema = z.object({
  role: z.enum(electableRoles, {
    required_error: 'Contested role is required',
    invalid_type_error: 'Role must be an electable leadership position',
  }),
  nomineeMembershipId: z
    .string({ required_error: 'Nominee membership ID is required' })
    .min(1, 'Nominee membership ID cannot be empty'),
  statement: z
    .string()
    .max(2000, 'Candidate statement must not exceed 2000 characters')
    .optional(),
});

export const respondNominationSchema = z.object({
  action: z.enum(['ACCEPT', 'DECLINE'], {
    required_error: 'Action must be either ACCEPT or DECLINE',
  }),
  statement: z
    .string()
    .max(2000, 'Candidate statement must not exceed 2000 characters')
    .optional(),
});

export const updateStatementSchema = z.object({
  statement: z
    .string({ required_error: 'Candidate statement is required' })
    .min(5, 'Candidate statement must be at least 5 characters')
    .max(2000, 'Candidate statement must not exceed 2000 characters'),
});

export const queryNominationsSchema = z.object({
  role: z.enum(electableRoles).optional(),
  status: z.enum(['PENDING', 'ACCEPTED', 'DECLINED', 'WITHDRAWN', 'ALL']).optional(),
  ballotOnly: z.coerce.boolean().optional(),
});

export type CreateNominationInput = z.infer<typeof createNominationSchema>;
export type RespondNominationInput = z.infer<typeof respondNominationSchema>;
export type UpdateStatementInput = z.infer<typeof updateStatementSchema>;
export type QueryNominationsInput = z.infer<typeof queryNominationsSchema>;
