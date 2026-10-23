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

// ── Email OTP Registration Flow Schemas ──────────────────────────────────────

export const sendEmailOtpSchema = z.object({
  email: z.string().email('Invalid email address'),
});

export const verifyEmailOtpSchema = z.object({
  email: z.string().email('Invalid email address'),
  otp: z
    .string()
    .length(6, 'OTP must be exactly 6 digits')
    .regex(/^\d{6}$/, 'OTP must contain numbers only'),
});

const nameRegex = /^[a-zA-Z\u1200-\u137F\s-]+$/;
const ethiopianPhoneRegex = /^\+251[79]\d{8}$/;

export const completeEmailRegistrationSchema = z
  .object({
    email: z.string().email('Invalid email address'),
    registrationToken: z.string().min(1, 'Registration token is required'),
    firstName: z
      .string()
      .min(2, 'First name must be at least 2 characters')
      .max(50, 'First name cannot exceed 50 characters')
      .regex(nameRegex, 'First name must contain letters, spaces, or hyphens only'),
    middleName: z
      .string()
      .min(2, 'Middle name must be at least 2 characters')
      .max(50, 'Middle name cannot exceed 50 characters')
      .regex(nameRegex, 'Middle name must contain letters, spaces, or hyphens only'),
    lastName: z
      .string()
      .min(2, 'Last name must be at least 2 characters')
      .max(50, 'Last name cannot exceed 50 characters')
      .regex(nameRegex, 'Last name must contain letters, spaces, or hyphens only'),
    phoneNumber: z
      .string()
      .length(13, 'Phone number must be exactly 13 characters (+2519XXXXXXXX or +2517XXXXXXXX)')
      .regex(
        ethiopianPhoneRegex,
        'Phone number must be Ethiopian format (+2519XXXXXXXX or +2517XXXXXXXX)'
      ),
    address: z
      .string()
      .min(3, 'Address must be at least 3 characters')
      .max(150, 'Address cannot exceed 150 characters'),
    dateOfBirth: z.coerce
      .date()
      .refine((d) => !isNaN(d.getTime()), 'Valid date of birth is required')
      .refine((d) => d <= new Date(), 'Date of birth cannot be in the future')
      .refine((d) => {
        const today = new Date();
        let age = today.getFullYear() - d.getFullYear();
        const monthDiff = today.getMonth() - d.getMonth();
        if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < d.getDate())) {
          age--;
        }
        return age >= 18;
      }, 'User must be at least 18 years old'),
    password: z
      .string()
      .min(12, 'Password must be at least 12 characters')
      .regex(/[A-Z]/, 'Password must contain at least 1 uppercase letter')
      .regex(/[a-z]/, 'Password must contain at least 1 lowercase letter')
      .regex(/[0-9]/, 'Password must contain at least 1 number')
      .regex(
        /[!@#$%^&*(),.?":{}|<>_\-\[\]\\;/+=`~]/,
        'Password must contain at least 1 special character'
      ),
    confirmPassword: z.string().optional(),
    fullName: z.string().optional(),
  })
  .refine((data) => !data.confirmPassword || data.password === data.confirmPassword, {
    message: 'Confirm password must match password',
    path: ['confirmPassword'],
  });

export const emailLoginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
  deviceInfo: z.string().optional(),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type RefreshTokenInput = z.infer<typeof refreshTokenSchema>;
export type SendEmailOtpInput = z.infer<typeof sendEmailOtpSchema>;
export type VerifyEmailOtpInput = z.infer<typeof verifyEmailOtpSchema>;
export type CompleteEmailRegistrationInput = z.infer<typeof completeEmailRegistrationSchema>;
export type EmailLoginInput = z.infer<typeof emailLoginSchema>;
