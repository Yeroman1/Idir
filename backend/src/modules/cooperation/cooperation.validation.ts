import { z } from 'zod';

export const proposeCooperationSchema = z.object({
  targetIdirId: z.string().uuid('Invalid target Idir ID'),
  purpose: z.string().min(3, 'Purpose must be at least 3 characters').max(200),
  description: z.string().min(5, 'Description must be at least 5 characters').max(2000),
  proposedDuration: z.coerce.number().int().positive().optional(),
});

export const respondCooperationSchema = z.object({
  action: z.enum(['accept', 'reject', 'ACCEPT', 'REJECT']),
  rejectionReason: z.string().max(500).optional(),
});

export const endCooperationSchema = z.object({
  reason: z.string().min(3, 'Reason must be at least 3 characters').max(500),
});

export const createInitiativeSchema = z.object({
  title: z.string().min(3).max(200),
  description: z.string().min(5),
  objectives: z.string().min(5),
  category: z.enum(['EMERGENCY_ASSISTANCE', 'COMMUNITY_SUPPORT', 'JOINT_MEETING', 'OTHER']).optional().default('OTHER'),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
});

export const updateInitiativeSchema = z.object({
  title: z.string().min(3).max(200).optional(),
  description: z.string().min(5).optional(),
  objectives: z.string().min(5).optional(),
  status: z.enum(['DRAFT', 'ACTIVE', 'COMPLETED', 'CANCELLED']).optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
});

export const addInitiativeUpdateSchema = z.object({
  content: z.string().min(2).max(2000),
});

export const addInitiativeTaskSchema = z.object({
  title: z.string().min(3).max(200),
  description: z.string().max(1000).optional(),
  responsibleIdirId: z.string().uuid('Invalid responsible Idir ID'),
  dueDate: z.string().optional(),
});

export const createCrossAnnouncementSchema = z.object({
  title: z.string().min(3).max(200),
  body: z.string().min(5).max(5000),
  category: z.enum(['EMERGENCY', 'JOINT_MEETING', 'COMMUNITY_INITIATIVE', 'GENERAL']).optional().default('GENERAL'),
});

export const updateCrossAnnouncementSchema = z.object({
  title: z.string().min(3).max(200).optional(),
  body: z.string().min(5).max(5000).optional(),
  category: z.enum(['EMERGENCY', 'JOINT_MEETING', 'COMMUNITY_INITIATIVE', 'GENERAL']).optional(),
});

export const createCrossEmergencySchema = z.object({
  title: z.string().min(3).max(200),
  description: z.string().min(5).max(5000),
  emergencyType: z.string().min(2).max(100),
  urgency: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']).optional().default('HIGH'),
});

export const respondCrossEmergencySchema = z.object({
  message: z.string().min(2).max(2000),
  commitmentNote: z.string().max(2000).optional(),
});

export const closeCrossEmergencySchema = z.object({
  outcomeSummary: z.string().min(3).max(2000),
});

export const createFinancialCommitmentSchema = z.object({
  amountCommitted: z.coerce.number().positive('Committed amount must be positive'),
  purpose: z.string().min(3).max(300),
  initiativeId: z.string().uuid().optional(),
});

export const confirmFinancialCommitmentSchema = z.object({
  amountConfirmed: z.coerce.number().positive('Confirmed amount must be positive'),
  reconciliationNote: z.string().max(1000).optional(),
});

export type ProposeCooperationInput = z.infer<typeof proposeCooperationSchema>;
export type RespondCooperationInput = z.infer<typeof respondCooperationSchema>;
export type EndCooperationInput = z.infer<typeof endCooperationSchema>;
export type CreateInitiativeInput = z.infer<typeof createInitiativeSchema>;
export type UpdateInitiativeInput = z.infer<typeof updateInitiativeSchema>;
export type AddInitiativeUpdateInput = z.infer<typeof addInitiativeUpdateSchema>;
export type AddInitiativeTaskInput = z.infer<typeof addInitiativeTaskSchema>;
export type CreateCrossAnnouncementInput = z.infer<typeof createCrossAnnouncementSchema>;
export type UpdateCrossAnnouncementInput = z.infer<typeof updateCrossAnnouncementSchema>;
export type CreateCrossEmergencyInput = z.infer<typeof createCrossEmergencySchema>;
export type RespondCrossEmergencyInput = z.infer<typeof respondCrossEmergencySchema>;
export type CloseCrossEmergencyInput = z.infer<typeof closeCrossEmergencySchema>;
export type CreateFinancialCommitmentInput = z.infer<typeof createFinancialCommitmentSchema>;
export type ConfirmFinancialCommitmentInput = z.infer<typeof confirmFinancialCommitmentSchema>;

