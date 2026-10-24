import { z } from 'zod';

export const updateProfileSchema = z.object({
  fullName: z.string().min(2).optional(),
  email: z.string().email().optional().nullable(),
  preferredLanguage: z.enum(['am', 'en', 'om']).optional(),
});

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;
