import { z } from 'zod';

export const updateProfileSchema = z.object({
  fullName: z.string().min(2).optional(),
  email: z.string().email().optional().nullable(),
  preferredLanguage: z.enum(['am', 'en', 'om']).optional(),
  faydaId: z.string().regex(/^\d{12}$/).optional().nullable(),
});

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;
