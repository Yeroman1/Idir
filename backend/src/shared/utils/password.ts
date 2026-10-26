import bcrypt from 'bcryptjs';

const SALT_ROUNDS = 12;

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password.trim(), SALT_ROUNDS);
}

export async function comparePassword(password: string, hash: string): Promise<boolean> {
  if (!password || !hash) return false;

  const candidatePasswords = [password];
  const trimmed = password.trim();
  if (trimmed !== password) {
    candidatePasswords.push(trimmed);
  }

  // Normalize hash salt version ($2b/$2y -> $2a) for cross-platform bcrypt compatibility
  const candidateHashes = [hash];
  const normalizedHash = hash.replace(/^\$2[by]\$/, '$2a$');
  if (normalizedHash !== hash) {
    candidateHashes.push(normalizedHash);
  }

  for (const p of candidatePasswords) {
    for (const h of candidateHashes) {
      try {
        const isMatch = await bcrypt.compare(p, h);
        if (isMatch) return true;
      } catch (_) {}
    }
  }

  return false;
}
