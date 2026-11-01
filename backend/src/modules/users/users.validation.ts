import { z } from 'zod';

export const updateProfileSchema = z.object({
  fullName: z.string().min(2, 'Full name must be at least 2 characters').max(100).optional(),
  phoneNumber: z
    .string()
    .regex(/^(\+251[79]\d{8}|0[79]\d{8}|\+?[1-9]\d{7,14})$/, 'Invalid phone number format')
    .optional(),
  address: z.string().max(255).optional().nullable(),
  preferredLanguage: z.enum(['am', 'en', 'om']).optional(),
  dateOfBirth: z.string().datetime().optional().nullable().or(z.date().optional()),
  // Email field in schema: we allow passing existing email, but mutating it will be rejected by service
  email: z.string().optional().nullable(),
});

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;
