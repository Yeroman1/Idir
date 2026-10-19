import { z } from 'zod';

export const createMeetingSchema = z.object({
  title: z.string().min(2, 'Meeting title is required'),
  agenda: z.string().optional(),
  location: z.string().optional(),
  scheduledAt: z.string().datetime().or(z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/)),
});

export const updateMeetingSchema = createMeetingSchema.partial().extend({
  status: z.enum(['SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']).optional(),
  minutes: z.string().optional(),
});

export const recordAttendanceSchema = z.object({
  membershipId: z.string().uuid(),
  status: z.enum(['PRESENT', 'ABSENT', 'EXCUSED', 'LATE']).default('PRESENT'),
  remarks: z.string().optional(),
});

export type CreateMeetingInput = z.infer<typeof createMeetingSchema>;
export type UpdateMeetingInput = z.infer<typeof updateMeetingSchema>;
export type RecordAttendanceInput = z.infer<typeof recordAttendanceSchema>;
