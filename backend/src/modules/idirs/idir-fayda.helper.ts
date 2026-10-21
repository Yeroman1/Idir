/**
 * Checks whether an authenticated user is verified with Ethiopian National ID (Fayda).
 * Plugs in cleanly for future KYC / Fayda biometric API extensions.
 */
export function isFaydaVerified(user?: { faydaId?: string | null } | null): boolean {
  if (!user || !user.faydaId) {
    return false;
  }
  return user.faydaId.trim().length > 0;
}
