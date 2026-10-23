import { Request, Response, NextFunction } from 'express';
import { authService } from './auth.service.js';
import { emailOtpService } from './email-otp.service.js';
import { sendSuccess, sendCreated } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';

export class AuthController {
  async register(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await authService.register(req.body, req.ip);
      return sendCreated(res, result, 'User registered successfully');
    } catch (error) {
      next(error);
    }
  }

  async login(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await authService.login(req.body, req.ip);
      return sendSuccess(res, result, 200, 'Login successful');
    } catch (error) {
      next(error);
    }
  }

  async refresh(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await authService.refreshToken(req.body, req.ip);
      return sendSuccess(res, result, 200, 'Tokens refreshed successfully');
    } catch (error) {
      next(error);
    }
  }

  async logout(req: Request, res: Response, next: NextFunction) {
    try {
      const refreshToken = req.body?.refreshToken;
      if (refreshToken) {
        await authService.logout(refreshToken);
      }
      return sendSuccess(res, { loggedOut: true }, 200, 'Logout successful');
    } catch (error) {
      next(error);
    }
  }

  async me(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const user = await authService.getMe(req.user!.id);
      return sendSuccess(res, user);
    } catch (error) {
      next(error);
    }
  }

  // ── Email OTP Registration Methods ─────────────────────────────────────────

  async sendEmailOtp(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await emailOtpService.sendOtp(req.body);
      return sendSuccess(res, result, 200, result.message);
    } catch (error) {
      next(error);
    }
  }

  async verifyEmailOtp(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await emailOtpService.verifyOtp(req.body);
      return sendSuccess(res, result, 200, result.message);
    } catch (error) {
      next(error);
    }
  }

  async completeEmailRegistration(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await emailOtpService.completeRegistration(req.body, req.ip);
      return sendCreated(res, result, result.message);
    } catch (error) {
      next(error);
    }
  }

  async emailLogin(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await emailOtpService.emailLogin(req.body, req.ip);
      return sendSuccess(res, result, 200, result.message);
    } catch (error) {
      next(error);
    }
  }
}

export const authController = new AuthController();
