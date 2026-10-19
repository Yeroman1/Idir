import { z } from 'zod';

export const addMemberSchema = z.object({
  userId: z.string().uuid().optional(),
  phoneNumber: z.string().optional(),
  memberNumber: z.string().min(1, 'Member number is required').optional(),
  role: z
    .enum(['CHAIRPERSON', 'TREASURER', 'SECRETARY', 'COMMITTEE', 'AUDITOR', 'MEMBER'])
    .default('MEMBER'),
});

export const updateMemberSchema = z.object({
  role: z
    .enum(['CHAIRPERSON', 'TREASURER', 'SECRETARY', 'COMMITTEE', 'AUDITOR', 'MEMBER'])
    .optional(),
  status: z.enum(['ACTIVE', 'PENDING', 'SUSPENDED', 'DEACTIVATED']).optional(),
  memberNumber: z.string().optional(),
});

export const queryMembersSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
  search: z.string().optional(),
  role: z
    .enum(['CHAIRPERSON', 'TREASURER', 'SECRETARY', 'COMMITTEE', 'AUDITOR', 'MEMBER'])
    .optional(),
  status: z.enum(['ACTIVE', 'PENDING', 'SUSPENDED', 'DEACTIVATED']).optional(),
});

export type AddMemberInput = z.infer<typeof addMemberSchema>;
export type UpdateMemberInput = z.infer<typeof updateMemberSchema>;
