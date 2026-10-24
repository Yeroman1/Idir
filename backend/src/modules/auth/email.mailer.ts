import nodemailer from 'nodemailer';
import { env } from '../../config/env.js';
import { logger } from '../../shared/utils/logger.js';

function getOtpHtml(otp: string, email: string, isPasswordReset = false): string {
  const title = isPasswordReset ? 'Reset Your Password' : 'Verify Your Email';
  const description = isPasswordReset
    ? `We received a request to reset the password for your account (<strong>${email}</strong>). Enter the verification code below to set a new password.`
    : `Thank you for registering. Enter the verification code below to activate your account for <strong>${email}</strong>.`;
  const footerNote = isPasswordReset
    ? `This code is valid for <strong>10 minutes</strong>. If you did not request a password reset, you can safely ignore this email.`
    : `This code is valid for <strong>10 minutes</strong>. If you did not request this verification, you can safely ignore this email.`;

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>${title}</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f9fafb; margin: 0; padding: 24px;">
  <div style="max-width: 480px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; padding: 32px; border: 1px solid #e5e7eb; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);">
    <div style="text-align: center; margin-bottom: 24px;">
      <h2 style="color: #111827; font-size: 24px; margin: 0 0 8px 0; font-weight: bold;">${title}</h2>
      <p style="color: #6b7280; font-size: 14px; margin: 0;">${description}</p>
    </div>

    <div style="background-color: #eff6ff; border: 2px dashed #3b82f6; border-radius: 12px; padding: 20px; text-align: center; margin: 28px 0;">
      <span style="font-family: 'Courier New', Courier, monospace; font-size: 36px; font-weight: 800; letter-spacing: 10px; color: #1d4ed8;">
        ${otp}
      </span>
    </div>

    <p style="color: #6b7280; font-size: 13px; text-align: center; margin-bottom: 24px;">
      ${footerNote}
    </p>

    <hr style="border: none; border-top: 1px solid #f3f4f6; margin: 24px 0;" />
    <p style="color: #9ca3af; font-size: 12px; text-align: center; margin: 0;">
      Idir Connect Mutual-Aid Association Platform
    </p>
  </div>
</body>
</html>
  `;
}

/**
 * Dispatches the 6-digit OTP email to the user's destination email address.
 * Automatically selects Resend API, configured SMTP, or Ethereal/Test Mailer.
 */
export async function sendOtpEmail(
  to: string,
  otp: string,
  isPasswordReset = false
): Promise<{ success: boolean; provider: string; previewUrl?: string }> {
  const subject = isPasswordReset
    ? `Your password reset verification code: ${otp}`
    : `Your 6-digit verification code: ${otp}`;

  // ── 1. Resend REST API (if RESEND_API_KEY is configured in .env) ───────────
  if (env.RESEND_API_KEY) {
    try {
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: env.EMAIL_FROM || 'Idir App <onboarding@resend.dev>',
          to: [to],
          subject,
          html: getOtpHtml(otp, to, isPasswordReset),
        }),
      });

      const resData = (await response.json()) as any;
      if (!response.ok) {
        logger.error({ resData }, 'Resend API returned error');
        throw new Error(resData?.message || 'Failed to send email via Resend API');
      }

      console.log(`[MAILER: RESEND] Successfully sent verification email to: ${to} (ID: ${resData.id})`);
      return { success: true, provider: 'resend' };
    } catch (err: any) {
      logger.error({ err }, 'Resend dispatch failed');
      throw err;
    }
  }

  // ── 2. Custom SMTP Transporter (if SMTP_HOST is configured in .env) ────────
  if (env.SMTP_HOST && env.SMTP_USER) {
    try {
      const cleanPass = env.SMTP_PASS ? env.SMTP_PASS.replace(/\s+/g, '') : undefined;
      const transporter = nodemailer.createTransport({
        host: env.SMTP_HOST,
        port: env.SMTP_PORT || 465,
        secure: env.SMTP_SECURE ?? (env.SMTP_PORT === 465),
        auth: {
          user: env.SMTP_USER,
          pass: cleanPass,
        },
      });

      const senderAddress = env.EMAIL_FROM && env.EMAIL_FROM.includes('@')
        ? env.EMAIL_FROM
        : `"${env.EMAIL_FROM || 'Idir Connect'}" <${env.SMTP_USER}>`;
      const info = await transporter.sendMail({
        from: senderAddress,
        to,
        subject,
        html: getOtpHtml(otp, to, isPasswordReset),
      });

      console.log(`[MAILER: SMTP] Verification email sent to ${to} (MessageId: ${info.messageId})`);
      return { success: true, provider: 'smtp' };
    } catch (err: any) {
      logger.error({ err }, 'SMTP dispatch failed');
      throw err;
    }
  }

  // ── 3. Ethereal Test Account Fallback (Instant Browser-Viewable Inbox) ─────
  try {
    const testAccount = await nodemailer.createTestAccount();
    const transporter = nodemailer.createTransport({
      host: 'smtp.ethereal.email',
      port: 587,
      secure: false,
      auth: {
        user: testAccount.user,
        pass: testAccount.pass,
      },
    });

    const info = await transporter.sendMail({
      from: '"Idir App" <verify@idir.org>',
      to,
      subject,
      html: getOtpHtml(otp, to, isPasswordReset),
    });

    const previewUrl = nodemailer.getTestMessageUrl(info) || undefined;

    console.log('\n' + '='.repeat(64));
    console.log(`  [REAL EMAIL DELIVERED TO TEST INBOX]`);
    console.log(`  Recipient: ${to}`);
    console.log(`  Code: [ ${otp} ]`);
    if (previewUrl) {
      console.log(`  >>> CLICK TO VIEW INBOX EMAIL: ${previewUrl} <<<`);
    }
    console.log('='.repeat(64) + '\n');

    return { success: true, provider: 'ethereal', previewUrl };
  } catch (err) {
    logger.warn({ err }, 'Fallback email generation failed');
    return { success: false, provider: 'none' };
  }
}

function getInvitationHtml(idirName: string, inviteUrl: string, inviterName?: string): string {
  const inviterText = inviterName ? `<strong>${inviterName}</strong> has invited you` : 'You have been invited';
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Invitation to join ${idirName}</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f9fafb; margin: 0; padding: 24px;">
  <div style="max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; padding: 36px; border: 1px solid #e5e7eb; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);">
    <div style="text-align: center; margin-bottom: 24px;">
      <div style="display: inline-block; background-color: #ecfdf5; border-radius: 50%; padding: 12px; margin-bottom: 12px;">
        <span style="font-size: 28px;">🤝</span>
      </div>
      <h2 style="color: #111827; font-size: 24px; margin: 0 0 8px 0; font-weight: bold;">Idir Invitation</h2>
      <p style="color: #4b5563; font-size: 15px; margin: 0; line-height: 1.5;">
        ${inviterText} to join <strong>${idirName}</strong> as a community member.
      </p>
    </div>

    <div style="background-color: #f3f4f6; border-radius: 12px; padding: 18px; margin: 24px 0; text-align: center;">
      <p style="color: #374151; font-size: 14px; margin: 0 0 4px 0; font-weight: 600;">Association</p>
      <p style="color: #111827; font-size: 18px; font-weight: 700; margin: 0;">${idirName}</p>
    </div>

    <div style="text-align: center; margin: 32px 0;">
      <a href="${inviteUrl}" style="background-color: #10b981; color: #ffffff; text-decoration: none; font-size: 16px; font-weight: bold; padding: 14px 32px; border-radius: 10px; display: inline-block; box-shadow: 0 2px 4px rgba(16, 185, 129, 0.3);">
        Accept Invitation
      </a>
    </div>

    <p style="color: #6b7280; font-size: 13px; text-align: center; margin-bottom: 16px; line-height: 1.5;">
      Button not working? Copy and paste this link into your browser:<br/>
      <a href="${inviteUrl}" style="color: #2563eb; word-break: break-all; font-size: 12px;">${inviteUrl}</a>
    </p>

    <hr style="border: none; border-top: 1px solid #f3f4f6; margin: 24px 0;" />
    <p style="color: #9ca3af; font-size: 12px; text-align: center; margin: 0;">
      Idir Connect — Ethiopian Community Mutual-Aid Association Platform
    </p>
  </div>
</body>
</html>
  `;
}

/**
 * Dispatches an Idir invitation email to the recipient with an accept link.
 */
export async function sendInvitationEmail(
  to: string,
  idirName: string,
  inviteUrl: string,
  inviterName?: string
): Promise<{ success: boolean; provider: string; previewUrl?: string }> {
  const subject = `Invitation to join ${idirName} on Idir Connect`;
  const html = getInvitationHtml(idirName, inviteUrl, inviterName);

  if (env.RESEND_API_KEY) {
    try {
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: env.EMAIL_FROM || 'Idir App <onboarding@resend.dev>',
          to: [to],
          subject,
          html,
        }),
      });

      const resData = (await response.json()) as any;
      if (!response.ok) {
        logger.error({ resData }, 'Resend API returned error for invitation');
        throw new Error(resData?.message || 'Failed to send invitation via Resend API');
      }

      console.log(`[MAILER: RESEND] Successfully sent invitation email to: ${to} (ID: ${resData.id})`);
      return { success: true, provider: 'resend' };
    } catch (err: any) {
      logger.error({ err }, 'Resend invitation dispatch failed');
      throw err;
    }
  }

  if (env.SMTP_HOST && env.SMTP_USER) {
    try {
      const cleanPass = env.SMTP_PASS ? env.SMTP_PASS.replace(/\s+/g, '') : undefined;
      const transporter = nodemailer.createTransport({
        host: env.SMTP_HOST,
        port: env.SMTP_PORT || 465,
        secure: env.SMTP_SECURE ?? (env.SMTP_PORT === 465),
        auth: {
          user: env.SMTP_USER,
          pass: cleanPass,
        },
      });

      const senderAddress = env.EMAIL_FROM && env.EMAIL_FROM.includes('@')
        ? env.EMAIL_FROM
        : `"${env.EMAIL_FROM || 'Idir Connect'}" <${env.SMTP_USER}>`;
      const info = await transporter.sendMail({
        from: senderAddress,
        to,
        subject,
        html,
      });

      console.log(`[MAILER: SMTP] Invitation email sent to ${to} for "${idirName}" (MessageId: ${info.messageId})`);
      return { success: true, provider: 'smtp' };
    } catch (err: any) {
      logger.error({ err }, 'SMTP invitation dispatch failed');
      throw err;
    }
  }

  try {
    const testAccount = await nodemailer.createTestAccount();
    const transporter = nodemailer.createTransport({
      host: 'smtp.ethereal.email',
      port: 587,
      secure: false,
      auth: {
        user: testAccount.user,
        pass: testAccount.pass,
      },
    });

    const info = await transporter.sendMail({
      from: '"Idir App" <invitations@idir.org>',
      to,
      subject,
      html,
    });

    const previewUrl = nodemailer.getTestMessageUrl(info) || undefined;
    console.log(`[MAILER: TEST] Invitation link for ${to}: ${inviteUrl}`);
    return { success: true, provider: 'ethereal', previewUrl };
  } catch (err) {
    logger.warn({ err }, 'Fallback invitation email generation failed');
    return { success: false, provider: 'none' };
  }
}

