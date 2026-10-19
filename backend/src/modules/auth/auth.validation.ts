import { z } from 'zod';

export const registerSchema = z.object({
  fullName: z.string().min(2, 'Full name must be at least 2 characters'),
  phoneNumber: z
    .string()
    .regex(/^\+?[0-9]{10,15}$/, 'Phone number must be valid (e.g. +251911234567 or 0911234567)'),
  password: z.string().min(6, 'Password must be at least 6 characters'),
  email: z.string().email('Invalid email address').optional(),
  preferredLanguage: z.enum(['am', 'en', 'om']).default('am'),
  faydaId: z
    .string()
    .regex(/^\d{12}$/, 'Fayda ID must be exactly 12 digits')
    .optional(),
});

export const loginSchema = z.object({
  phoneNumber: z.string().min(1, 'Phone number is required'),
  password: z.string().min(1, 'Password is required'),
  deviceInfo: z.string().optional(),
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type RefreshTokenInput = z.infer<typeof refreshTokenSchema>;
