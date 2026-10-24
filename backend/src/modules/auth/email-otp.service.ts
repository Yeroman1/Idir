import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { prisma } from '../../config/database.js';
import { env } from '../../config/env.js';
import { hashPassword, comparePassword } from '../../shared/utils/password.js';
import {
  generateAccessToken,
  generateRefreshToken,
  hashToken,
} from '../../shared/utils/jwt.js';
import {
  BadRequestError,
  ConflictError,
  UnauthorizedError,
  RateLimitError,
  NotFoundError,
} from '../../shared/errors/AppError.js';
import {
  SendEmailOtpInput,
  VerifyEmailOtpInput,
  CompleteEmailRegistrationInput,
  EmailLoginInput,
  ForgotPasswordResetInput,
} from './auth.validation.js';
import { sendOtpEmail } from './email.mailer.js';

interface OtpRecord {
  hash: string;
  expiresAt: number;
  attempts: number;
  resendAfter: number;
}

export class EmailOtpService {
  // Thread-safe in-memory OTP storage with TTL
  private otpStore = new Map<string, OtpRecord>();

  constructor() {
    // Periodically clean up expired OTP records every 5 minutes
    setInterval(() => {
      const now = Date.now();
      for (const [email, record] of this.otpStore.entries()) {
        if (record.expiresAt < now) {
          this.otpStore.delete(email);
        }
      }
    }, 5 * 60 * 1000).unref();
  }

  private hashOtp(otp: string): string {
    return crypto.createHash('sha256').update(otp).digest('hex');
  }

  /**
   * Step 1: User enters email. Backend generates 6-digit OTP, stores it,
   * prints to backend console, and dispatches it.
   */
  async sendOtp(input: SendEmailOtpInput) {
    const email = input.email.trim().toLowerCase();

    // Check if an account already exists with this email
    const existing = await prisma.user.findUnique({
      where: { email },
    });
    if (existing) {
      throw new ConflictError(
        'An account with this email address already exists. Please log in.'
      );
    }

    // Rate-limiting check: enforce a 60-second cooldown between requests
    const current = this.otpStore.get(email);
    if (current && Date.now() < current.resendAfter) {
      const waitSeconds = Math.ceil((current.resendAfter - Date.now()) / 1000);
      throw new RateLimitError(
        `Please wait ${waitSeconds}s before requesting a new verification code.`
      );
    }

    // Generate secure 6-digit OTP code
    const rawCode = crypto.randomInt(100000, 999999).toString();
    const hash = this.hashOtp(rawCode);

    // Save record with 10-minute validity and 60-second cooldown
    this.otpStore.set(email, {
      hash,
      expiresAt: Date.now() + 10 * 60 * 1000,
      attempts: 0,
      resendAfter: Date.now() + 60 * 1000,
    });

    // ── Dispatch real email via Resend, SMTP, or test mailer ─────────────
    const mailResult = await sendOtpEmail(email, rawCode);

    return {
      success: true,
      email,
      message: `Verification code sent to ${email}`,
      mailProvider: mailResult.provider,
      ...(mailResult.previewUrl && { previewUrl: mailResult.previewUrl }),
      ...(env.NODE_ENV !== 'production' && { devOtp: rawCode }),
    };
  }

  /**
   * Step 2: Validate the 6-digit code.
   * If correct, issue a short-lived signed registrationToken to allow password creation.
   */
  async verifyOtp(input: VerifyEmailOtpInput) {
    const email = input.email.trim().toLowerCase();
    const otp = input.otp.trim();

    const record = this.otpStore.get(email);
    if (!record) {
      throw new BadRequestError(
        'No active verification code found for this email. Please request a new code.'
      );
    }

    if (Date.now() > record.expiresAt) {
      this.otpStore.delete(email);
      throw new BadRequestError(
        'Verification code has expired. Please request a new code.'
      );
    }

    if (record.attempts >= 5) {
      this.otpStore.delete(email);
      throw new BadRequestError(
        'Too many invalid attempts. For security, please request a new verification code.'
      );
    }

    record.attempts += 1;

    const providedHash = this.hashOtp(otp);
    if (providedHash !== record.hash) {
      throw new BadRequestError(
        'Incorrect 6-digit verification code. Please check and try again.'
      );
    }

    // Verified successfully — remove OTP
    this.otpStore.delete(email);

    // Issue tamper-proof JWT token granting permission to create a password for this email (15-min validity)
    const registrationToken = jwt.sign(
      { email, purpose: 'email_registration_verified' },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    return {
      success: true,
      email,
      message: 'Email verified successfully. You may now create your password.',
      registrationToken,
    };
  }

  /**
   * Step 3: Complete registration by setting the password.
   */
  async completeRegistration(
    input: CompleteEmailRegistrationInput,
    ipAddress?: string
  ) {
    const email = input.email.trim().toLowerCase();

    // Verify registration token
    try {
      const decoded = jwt.verify(
        input.registrationToken,
        env.JWT_ACCESS_SECRET
      ) as { email: string; purpose: string };

      if (
        decoded.email !== email ||
        decoded.purpose !== 'email_registration_verified'
      ) {
        throw new UnauthorizedError(
          'Invalid or mismatched registration verification token.'
        );
      }
    } catch {
      throw new UnauthorizedError(
        'Registration token has expired or is invalid. Please verify your email again.'
      );
    }

    // Double-check email conflict
    const existingEmail = await prisma.user.findUnique({
      where: { email },
    });
    if (existingEmail) {
      throw new ConflictError('An account with this email address already exists. Please log in.');
    }

    // Double-check phone number conflict
    const existingPhone = await prisma.user.findUnique({
      where: { phoneNumber: input.phoneNumber },
    });
    if (existingPhone) {
      throw new ConflictError('An account with this phone number already exists.');
    }

    const passwordHash = await hashPassword(input.password);
    const finalFullName =
      input.fullName ||
      `${input.firstName.trim()} ${input.middleName.trim()} ${input.lastName.trim()}`.trim();

    // ── Sync with Supabase Auth (auth.users) ──────────────────────────────────
    let supabaseUserId: string | undefined;
    if (env.SUPABASE_URL && env.SUPABASE_ANON_KEY) {
      try {
        const sbResponse = await fetch(`${env.SUPABASE_URL}/auth/v1/signup`, {
          method: 'POST',
          headers: {
            apikey: env.SUPABASE_ANON_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            email,
            password: input.password,
            data: {
              first_name: input.firstName.trim(),
              middle_name: input.middleName.trim(),
              last_name: input.lastName.trim(),
              full_name: finalFullName,
              phone_number: input.phoneNumber.trim(),
              address: input.address.trim(),
              date_of_birth: input.dateOfBirth,
            },
          }),
        });

        if (sbResponse.ok) {
          const sbData = (await sbResponse.json()) as any;
          if (sbData?.id) {
            supabaseUserId = sbData.id;
            console.log(`[SUPABASE AUTH] Successfully registered user in Supabase Auth (${sbData.id})`);
          }
        }
      } catch (sbErr) {
        console.warn('[SUPABASE AUTH] Supabase Auth sync notice:', sbErr);
      }
    }

    const user = await prisma.user.create({
      data: {
        ...(supabaseUserId && { id: supabaseUserId }),
        email,
        fullName: finalFullName,
        firstName: input.firstName.trim(),
        middleName: input.middleName.trim(),
        lastName: input.lastName.trim(),
        phoneNumber: input.phoneNumber.trim(),
        address: input.address.trim(),
        dateOfBirth: new Date(input.dateOfBirth),
        passwordHash,
        preferredLanguage: 'am',
        status: 'ACTIVE',
      },
      select: {
        id: true,
        fullName: true,
        firstName: true,
        middleName: true,
        lastName: true,
        phoneNumber: true,
        email: true,
        address: true,
        dateOfBirth: true,
        preferredLanguage: true,
        status: true,
        isPlatformAdmin: true,
        createdAt: true,
        memberships: {
          include: {
            idir: {
              select: {
                id: true,
                name: true,
                currency: true,
                status: true,
              },
            },
          },
        },
      },
    });

    const tokenPayload = {
      userId: user.id,
      phoneNumber: user.phoneNumber,
      isPlatformAdmin: user.isPlatformAdmin,
    };

    const accessToken = generateAccessToken(tokenPayload);
    const refreshToken = generateRefreshToken(tokenPayload);
    const family = crypto.randomUUID();

    await prisma.refreshToken.create({
      data: {
        tokenHash: hashToken(refreshToken),
        userId: user.id,
        family,
        ipAddress,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
      },
    });

    return {
      success: true,
      message: 'Account created successfully',
      user,
      tokens: { accessToken, refreshToken },
    };
  }

  /**
   * Step 4: Login using Email and Password
   */
  async emailLogin(input: EmailLoginInput, ipAddress?: string) {
    const email = input.email.trim().toLowerCase();

    const user = await prisma.user.findUnique({
      where: { email },
      include: {
        memberships: {
          include: {
            idir: {
              select: {
                id: true,
                name: true,
                currency: true,
              },
            },
          },
        },
      },
    });

    if (!user) {
      throw new UnauthorizedError('Invalid email or password');
    }

    if (user.status !== 'ACTIVE') {
      throw new UnauthorizedError('User account is suspended or inactive');
    }

    const isMatch = await comparePassword(input.password, user.passwordHash);
    if (!isMatch) {
      throw new UnauthorizedError('Invalid email or password');
    }

    const tokenPayload = {
      userId: user.id,
      phoneNumber: user.phoneNumber,
      isPlatformAdmin: user.isPlatformAdmin,
    };

    const accessToken = generateAccessToken(tokenPayload);
    const refreshToken = generateRefreshToken(tokenPayload);
    const family = crypto.randomUUID();

    await prisma.refreshToken.create({
      data: {
        tokenHash: hashToken(refreshToken),
        userId: user.id,
        family,
        ipAddress,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
    });

    return {
      success: true,
      message: 'Login successful',
      user: {
        id: user.id,
        fullName: user.fullName,
        phoneNumber: user.phoneNumber,
        email: user.email,
        preferredLanguage: user.preferredLanguage,
        status: user.status,
        isPlatformAdmin: user.isPlatformAdmin,
        createdAt: user.createdAt,
        memberships: user.memberships,
      },
      tokens: { accessToken, refreshToken },
    };
  }

  /**
   * Step 1 (Forgot Password): User enters email. Backend checks if user is registered,
   * generates 6-digit OTP, stores it with cooldown, dispatches email via SMTP,
   * and prints to console.
   */
  async sendForgotPasswordOtp(input: SendEmailOtpInput) {
    const email = input.email.trim().toLowerCase();

    // 1. Check first if the email is an actual registered user
    const user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      // Also check if user exists in auth.users
      const authUser = await prisma.$queryRawUnsafe<any[]>(
        'SELECT id FROM auth.users WHERE LOWER(email) = LOWER($1) LIMIT 1',
        email
      ).catch(() => []);

      if (!authUser || authUser.length === 0) {
        throw new NotFoundError(
          'This email is not registered. Please check the email or sign up first.'
        );
      }
    }

    // Rate-limiting check: enforce a 60-second cooldown between requests
    const storeKey = `pwd_reset_${email}`;
    const current = this.otpStore.get(storeKey);
    if (current && Date.now() < current.resendAfter) {
      const waitSeconds = Math.ceil((current.resendAfter - Date.now()) / 1000);
      throw new RateLimitError(
        `Please wait ${waitSeconds}s before requesting a new verification code.`
      );
    }

    // Generate secure 6-digit OTP code
    const rawCode = crypto.randomInt(100000, 999999).toString();
    const hash = this.hashOtp(rawCode);

    // Save record with 10-minute validity and 60-second cooldown
    this.otpStore.set(storeKey, {
      hash,
      expiresAt: Date.now() + 10 * 60 * 1000,
      attempts: 0,
      resendAfter: Date.now() + 60 * 1000,
    });

    console.log(`\n================================================================`);
    console.log(`  [PASSWORD RESET OTP]`);
    console.log(`  Email: ${email}`);
    console.log(`  Code:  [ ${rawCode} ]`);
    console.log(`================================================================\n`);

    // ── Dispatch real password reset email via configured mailer ───────────
    const mailResult = await sendOtpEmail(email, rawCode, true);

    return {
      success: true,
      email,
      message: `Password reset verification code sent to ${email}`,
      mailProvider: mailResult.provider,
      ...(mailResult.previewUrl && { previewUrl: mailResult.previewUrl }),
      ...(env.NODE_ENV !== 'production' && { devOtp: rawCode }),
    };
  }

  /**
   * Step 2 (Forgot Password): Validate the 6-digit OTP code for password reset.
   * If correct, issue a short-lived signed resetToken to allow new password creation.
   */
  async verifyForgotPasswordOtp(input: VerifyEmailOtpInput) {
    const email = input.email.trim().toLowerCase();
    const otp = input.otp.trim();
    const storeKey = `pwd_reset_${email}`;

    const record = this.otpStore.get(storeKey);
    if (!record) {
      throw new BadRequestError(
        'No active password reset verification code found. Please request a new code.'
      );
    }

    if (Date.now() > record.expiresAt) {
      this.otpStore.delete(storeKey);
      throw new BadRequestError(
        'Verification code has expired. Please request a new code.'
      );
    }

    if (record.attempts >= 5) {
      this.otpStore.delete(storeKey);
      throw new BadRequestError(
        'Too many invalid attempts. For security, please request a new verification code.'
      );
    }

    record.attempts += 1;

    const providedHash = this.hashOtp(otp);
    if (providedHash !== record.hash) {
      throw new BadRequestError(
        'Incorrect 6-digit verification code. Please check and try again.'
      );
    }

    // Code is correct: consume the OTP
    this.otpStore.delete(storeKey);

    // Issue short-lived reset token (valid for 15 minutes)
    const resetToken = jwt.sign(
      { email, purpose: 'password_reset_verified' },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    return {
      success: true,
      email,
      resetToken,
      message: 'Code verified successfully. Please enter your new password.',
    };
  }

  /**
   * Step 3 (Forgot Password): Set new password using verified resetToken.
   * Updates password in Prisma PostgreSQL AND live Supabase auth.users.
   */
  async resetPassword(input: ForgotPasswordResetInput) {
    const email = input.email.trim().toLowerCase();

    // 1. Validate JWT reset token
    try {
      const decoded = jwt.verify(
        input.resetToken,
        env.JWT_ACCESS_SECRET
      ) as { email: string; purpose: string };

      if (
        decoded.email !== email ||
        decoded.purpose !== 'password_reset_verified'
      ) {
        throw new UnauthorizedError(
          'Invalid or mismatched password reset token.'
        );
      }
    } catch {
      throw new UnauthorizedError(
        'Password reset session has expired or is invalid. Please request a new verification code.'
      );
    }

    // 2. Hash new password
    const passwordHash = await hashPassword(input.password);

    // 3. Update password in Prisma PostgreSQL User table
    await prisma.user.updateMany({
      where: { email },
      data: { passwordHash },
    });

    // 4. Update password in Supabase Auth (auth.users)
    try {
      await prisma.$executeRawUnsafe(
        `UPDATE auth.users SET encrypted_password = crypt($1, gen_salt('bf')) WHERE LOWER(email) = LOWER($2)`,
        input.password,
        email
      );
      console.log(`[AUTH: PASSWORD RESET] Synced updated password to auth.users for ${email}`);
    } catch (sbErr) {
      console.warn('[AUTH: PASSWORD RESET] Notice updating auth.users password:', sbErr);
    }

    return {
      success: true,
      email,
      message: 'Password reset successfully. You can now log in with your new password.',
    };
  }
}

export const emailOtpService = new EmailOtpService();
