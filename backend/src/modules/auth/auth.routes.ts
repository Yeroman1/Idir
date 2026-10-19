import { Router } from 'express';
import { authController } from './auth.controller.js';
import { validate } from '../../middleware/validate.js';
import { authenticate } from '../../middleware/authenticate.js';
import { authLimiter } from '../../middleware/rateLimiter.js';
import {
  registerSchema,
  loginSchema,
  refreshTokenSchema,
} from './auth.validation.js';

const router = Router();

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

export const authRoutes = router;
