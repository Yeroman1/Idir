import crypto from 'crypto';
import { ValidationError } from '../../shared/errors/AppError.js';

/**
 * Normalizes an Ethiopian mobile phone number to E.164 format (+2519XXXXXXXX or +2517XXXXXXXX).
 * Accepts:
 *  - 0911223344 / 0711223344 (10 digits)
 *  - 911223344 / 711223344 (9 digits)
 *  - 251911223344 / 251711223344 (12 digits)
 *  - +251911223344 / +251711223344 (13 characters)
 *
 * Strips whitespace, hyphens, and parentheses.
 *
 * @param phone Raw phone string
 * @returns Normalized phone string in E.164 format (+251...)
 * @throws ValidationError if phone format is invalid
 */
export function normalizeEthPhone(phone: string): string {
  if (!phone || typeof phone !== 'string') {
    throw new ValidationError('Phone number is required');
  }

  // Remove whitespace, dashes, dots, parentheses
  let cleaned = phone.trim().replace(/[\s\-\(\)\.]/g, '');

  if (cleaned.startsWith('+251')) {
    // Already has +251 prefix
  } else if (cleaned.startsWith('251')) {
    cleaned = `+${cleaned}`;
  } else if (cleaned.startsWith('0') && (cleaned.startsWith('09') || cleaned.startsWith('07'))) {
    cleaned = `+251${cleaned.substring(1)}`;
  } else if (cleaned.startsWith('9') || cleaned.startsWith('7')) {
    cleaned = `+251${cleaned}`;
  }

  // Validate E.164 format for Ethiopian mobile: +251 followed by 7 or 9 and 8 digits
  const ethRegex = /^\+251[79]\d{8}$/;
  if (!ethRegex.test(cleaned)) {
    throw new ValidationError(
      `Invalid Ethiopian mobile phone number "${phone}". Must be a 9-digit or 10-digit mobile number starting with 09 or 07.`
    );
  }

  return cleaned;
}

/**
 * Validates whether a phone number is a valid Ethiopian mobile number.
 */
export function isValidEthPhone(phone: string): boolean {
  try {
    normalizeEthPhone(phone);
    return true;
  } catch {
    return false;
  }
}

/**
 * Generates a high-entropy, cryptographically secure invitation token (32 random bytes)
 * and its SHA-256 hash. The raw token is sent to the invitee via SMS/link, and only the
 * hash is saved in the database.
 */
export function generateInvitationToken(): { rawToken: string; tokenHash: string } {
  const rawToken = crypto.randomBytes(32).toString('hex');
  const tokenHash = hashInvitationToken(rawToken);
  return { rawToken, tokenHash };
}

/**
 * Computes the SHA-256 hash of an invitation token for lookup and verification.
 */
export function hashInvitationToken(rawToken: string): string {
  return crypto.createHash('sha256').update(rawToken).digest('hex');
}
