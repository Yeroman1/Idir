/**
 * Checks whether an authenticated user is verified/eligible to create an Idir.
 * Users with Fayda ID, verified email, or registered phone numbers are eligible.
 */
export function isFaydaVerified(
  user?: { id?: string; faydaId?: string | null; email?: string | null; phoneNumber?: string | null } | null
): boolean {
  if (!user) {
    return false;
  }
  return Boolean(
    (user.faydaId && user.faydaId.trim().length > 0) ||
    (user.email && user.email.trim().length > 0) ||
    (user.phoneNumber && user.phoneNumber.trim().length > 0) ||
    Boolean(user.id)
  );
}

