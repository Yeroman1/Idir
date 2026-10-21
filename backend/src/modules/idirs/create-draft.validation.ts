import { z } from 'zod';

export const createDraftIdirSchema = z.object({
  name: z
    .string({ required_error: 'Idir name is required' })
    .min(2, 'Idir name must be at least 2 characters')
    .max(120, 'Idir name must not exceed 120 characters'),
  community: z
    .string({ required_error: 'Community is required' })
    .min(2, 'Community must be at least 2 characters')
    .max(120, 'Community must not exceed 120 characters'),
  location: z
    .string({ required_error: 'Location is required' })
    .min(2, 'Location must be at least 2 characters')
    .max(255, 'Location must not exceed 255 characters'),
  purpose: z
    .string({ required_error: 'Purpose is required' })
    .min(5, 'Purpose must be at least 5 characters')
    .max(500, 'Purpose must not exceed 500 characters'),
  contributionAmount: z.coerce
    .number({ required_error: 'Contribution amount is required' })
    .positive('Contribution amount must be greater than 0'),
  contributionFrequency: z.enum(['WEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY'], {
    required_error: 'Contribution frequency is required',
    invalid_type_error:
      'Contribution frequency must be one of: WEEKLY, MONTHLY, QUARTERLY, YEARLY',
  }),
  rules: z.string().max(5000, 'Rules must not exceed 5000 characters').optional(),
});

export type CreateDraftIdirInput = z.infer<typeof createDraftIdirSchema>;
