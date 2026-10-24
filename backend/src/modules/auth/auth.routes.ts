import { Router } from 'express';
import { authController } from './auth.controller.js';
import { validate } from '../../middleware/validate.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authLimiter } from '../../middleware/rateLimiter.js';
import {
  registerSchema,
  loginSchema,
  refreshTokenSchema,
  sendEmailOtpSchema,
  verifyEmailOtpSchema,
  completeEmailRegistrationSchema,
  emailLoginSchema,
  forgotPasswordResetSchema,
} from './auth.validation.js';

const router = Router();

// ── Standard Phone/Credentials Auth ──────────────────────────────────────────
router.post(
  '/register',
  authLimiter,
  validate({ body: registerSchema }),
  authController.register
);

router.post(
  '/login',
  authLimiter,
  validate({ body: loginSchema }),
  authController.login
);

router.post(
  '/refresh',
  authLimiter,
  validate({ body: refreshTokenSchema }),
  authController.refresh
);

router.post(
  '/logout',
  validate({ body: refreshTokenSchema }),
  authController.logout
);

router.get(
  '/me',
  authenticate,
  authController.me
);

// ── Email OTP Registration Flow (Zero External APIs Required) ────────────────
router.post(
  '/email/send-otp',
  authLimiter,
  validate({ body: sendEmailOtpSchema }),
  authController.sendEmailOtp
);

router.post(
  '/email/verify-otp',
  authLimiter,
  validate({ body: verifyEmailOtpSchema }),
  authController.verifyEmailOtp
);

router.post(
  '/email/complete-registration',
  authLimiter,
  validate({ body: completeEmailRegistrationSchema }),
  authController.completeEmailRegistration
);

router.post(
  '/email/login',
  authLimiter,
  validate({ body: emailLoginSchema }),
  authController.emailLogin
);

// ── Forgot Password Flow (Email OTP with SMTP + Registration Check) ──────────
router.post(
  '/email/forgot-password/send-otp',
  authLimiter,
  validate({ body: sendEmailOtpSchema }),
  authController.sendForgotPasswordOtp
);

router.post(
  '/email/forgot-password/verify-otp',
  authLimiter,
  validate({ body: verifyEmailOtpSchema }),
  authController.verifyForgotPasswordOtp
);

router.post(
  '/email/forgot-password/reset-password',
  authLimiter,
  validate({ body: forgotPasswordResetSchema }),
  authController.resetPassword
);

export const authRoutes = router;
