import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/config/database.js';
import { generateAccessToken } from '../src/shared/utils/jwt.js';
import { normalizeEthPhone, isValidEthPhone, generateInvitationToken, hashInvitationToken } from '../src/modules/invitations/invitation-crypto.js';
import { smsService } from '../src/modules/invitations/sms.service.js';

vi.mock('../src/config/database.js', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    idir: { findUnique: vi.fn(), create: vi.fn() },
    membership: { findFirst: vi.fn(), findUnique: vi.fn(), create: vi.fn(), count: vi.fn(), update: vi.fn() },
    invitation: { count: vi.fn(), upsert: vi.fn(), findFirst: vi.fn(), findUnique: vi.fn(), findMany: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
    $transaction: vi.fn((callback) => callback(prisma)),
  },
}));

describe('Stage 4: Phone Invitations & Cryptographic Tokens', () => {
  const creatorUserId = 'creator-uuid-001';
  const officerUserId = 'officer-uuid-002';
  const memberUserId = 'regular-member-uuid-003';
  const idirId = 'idir-uuid-test';

  let creatorToken: string;
  let officerToken: string;
  let memberToken: string;

  beforeEach(() => {
    vi.clearAllMocks();
    smsService.clearHistory();

    creatorToken = generateAccessToken({
      userId: creatorUserId,
      phoneNumber: '+251911000001',
      isPlatformAdmin: false,
    });

    officerToken = generateAccessToken({
      userId: officerUserId,
      phoneNumber: '+251911000002',
      isPlatformAdmin: false,
    });

    memberToken = generateAccessToken({
      userId: memberUserId,
      phoneNumber: '+251911000003',
      isPlatformAdmin: false,
    });

    // Default mock user profile for authentication middleware
    vi.mocked(prisma.user.findUnique).mockImplementation(async ({ where }: any) => {
      const id = where.id;
      return {
        id,
        fullName: 'Test User',
        phoneNumber: '+251911000000',
        email: null,
        faydaId: 'FAYDA-12345',
        status: 'ACTIVE',
        isPlatformAdmin: false,
        preferredLanguage: 'am',
      } as any;
    });

    // Default mock for Idir
    vi.mocked(prisma.idir.findUnique).mockResolvedValue({
      id: idirId,
      name: 'Yeka Michael Idir',
      createdById: creatorUserId,
      status: 'DRAFT',
    } as any);

    // Default mock for invitation count (0 sent recently)
    vi.mocked(prisma.invitation.count).mockResolvedValue(0);

    // Default mock for upsert
    vi.mocked(prisma.invitation.upsert).mockImplementation(async ({ create }: any) => {
      return {
        id: `invite-${Math.random().toString(36).substring(7)}`,
        ...create,
      } as any;
    });
  });

  describe('1. Phone Normalizer & Crypto Token Generator', () => {
    it('normalizes various Ethiopian phone formats to strict E.164 (+251...) format', () => {
      expect(normalizeEthPhone('0911223344')).toBe('+251911223344');
      expect(normalizeEthPhone('0712345678')).toBe('+251712345678');
      expect(normalizeEthPhone('+251911223344')).toBe('+251911223344');
      expect(normalizeEthPhone('251911223344')).toBe('+251911223344');
      expect(normalizeEthPhone('911223344')).toBe('+251911223344');
      expect(normalizeEthPhone('712345678')).toBe('+251712345678');
      expect(normalizeEthPhone('  +251 911-22-33-44 ')).toBe('+251911223344');
    });

    it('rejects invalid or non-mobile Ethiopian numbers', () => {
      expect(isValidEthPhone('0111223344')).toBe(false); // Addis landline (011)
      expect(isValidEthPhone('12345')).toBe(false);
      expect(isValidEthPhone('+14155552671')).toBe(false);
      expect(isValidEthPhone('')).toBe(false);
    });

    it('generates high-entropy random token and matching SHA-256 hash', () => {
      const { rawToken, tokenHash } = generateInvitationToken();
      expect(rawToken).toHaveLength(64); // 32 bytes in hex = 64 characters
      expect(tokenHash).toHaveLength(64); // SHA-256 hex = 64 characters
      expect(hashInvitationToken(rawToken)).toBe(tokenHash);
    });
  });

  describe('2. Permissions for Batch Invitations', () => {
    it('allows the Idir creator to send batch invitations (even in DRAFT status)', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/invitations/batch`)
        .set('Authorization', `Bearer ${creatorToken}`)
        .send({
          phoneNumbers: ['0911223344', '0922334455'],
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.sentCount).toBe(2);
      expect(res.body.data.invitations).toHaveLength(2);
      expect(res.body.data.invitations[0].phoneNumber).toBe('+251911223344');
      expect(res.body.data.invitations[0].inviteUrl).toContain('token=');
      // Verify SMS was dispatched
      expect(smsService.getSentHistory()).toHaveLength(2);
    });

    it('allows an active officer (Secretary/Chairperson) to send invitations', async () => {
      // Mock officer membership for actor while allowing invitee to not match active membership
      vi.mocked(prisma.membership.findFirst).mockImplementation(async ({ where }: any) => {
        if (where?.userId === officerUserId) {
          return {
            id: 'membership-officer',
            idirId,
            userId: officerUserId,
            role: 'SECRETARY',
            status: 'ACTIVE',
          } as any;
        }
        return null;
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/invitations/batch`)
        .set('Authorization', `Bearer ${officerToken}`)
        .send({
          phoneNumbers: ['0933445566'],
        });

      expect(res.status).toBe(201);
      expect(res.body.data.sentCount).toBe(1);
    });

    it('rejects regular members who are not officers with 403 Forbidden', async () => {
      // Mock no officer membership
      vi.mocked(prisma.membership.findFirst).mockResolvedValue(null);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/invitations/batch`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          phoneNumbers: ['0944556677'],
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('FORBIDDEN');
      expect(res.body.error.message).toContain('Only the Idir creator or authorized officers');
    });
  });

  describe('3. Validation, Deduplication, & Skipping Existing Active Members', () => {
    it('deduplicates phone numbers within the batch and skips invalid numbers', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/invitations/batch`)
        .set('Authorization', `Bearer ${creatorToken}`)
        .send({
          phoneNumbers: [
            '0911223344',
            '+251 911 22 33 44', // Duplicate of 0911223344
            '0111223344', // Invalid landline
            '0955667788', // Valid unique
          ],
        });

      expect(res.status).toBe(201);
      expect(res.body.data.sentCount).toBe(2); // 0911223344 and 0955667788
      expect(res.body.data.skipped).toHaveLength(2);
      expect(res.body.data.skipped[0].reason).toContain('Duplicate');
      expect(res.body.data.skipped[1].reason).toContain('Invalid Ethiopian');
    });

    it('skips numbers belonging to users who are already active members of the Idir', async () => {
      // Mock that +251911223344 is an existing active member
      vi.mocked(prisma.membership.findFirst).mockImplementation(async ({ where }: any) => {
        if (where?.user?.phoneNumber === '+251911223344') {
          return { id: 'existing-active-member-id' } as any;
        }
        return null;
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/invitations/batch`)
        .set('Authorization', `Bearer ${creatorToken}`)
        .send({
          phoneNumbers: ['0911223344', '0988776655'],
        });

      expect(res.status).toBe(201);
      expect(res.body.data.sentCount).toBe(1);
      expect(res.body.data.invitations[0].phoneNumber).toBe('+251988776655');
      expect(res.body.data.skipped).toHaveLength(1);
      expect(res.body.data.skipped[0].phoneNumber).toBe('+251911223344');
      expect(res.body.data.skipped[0].reason).toContain('already an active member');
    });
  });

  describe('4. Token Security & Storage', () => {
    it('never stores the rawToken in the database, only stores tokenHash', async () => {
      let savedTokenHash: string | undefined;
      vi.mocked(prisma.invitation.upsert).mockImplementation(async ({ create }: any) => {
        savedTokenHash = create.tokenHash;
        return { id: 'invite-1', ...create } as any;
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/invitations/batch`)
        .set('Authorization', `Bearer ${creatorToken}`)
        .send({
          phoneNumbers: ['0911998877'],
        });

      expect(res.status).toBe(201);
      const inviteUrl = res.body.data.invitations[0].inviteUrl;
      const rawToken = new URL(inviteUrl).searchParams.get('token');
      expect(rawToken).toBeDefined();

      // Ensure rawToken was hashed before being saved
      expect(savedTokenHash).toBeDefined();
      expect(savedTokenHash).not.toBe(rawToken);
      expect(hashInvitationToken(rawToken!)).toBe(savedTokenHash);
    });
  });

  describe('5. Rate Limiting Enforced', () => {
    it('rejects batch if recent invitations exceed 100 per hour with 429 RateLimitError', async () => {
      // Mock that 95 invitations were already sent in the last hour
      vi.mocked(prisma.invitation.count).mockResolvedValue(95);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/invitations/batch`)
        .set('Authorization', `Bearer ${creatorToken}`)
        .send({
          phoneNumbers: ['0911000001', '0911000002', '0911000003', '0911000004', '0911000005', '0911000006'], // 6 numbers -> 95 + 6 = 101 > 100
        });

      expect(res.status).toBe(429);
      expect(res.body.error.code).toBe('RATE_LIMIT_EXCEEDED');
      expect(res.body.error.message).toContain('rate limit exceeded');
    });
  });

  describe('6. Stage 5: Public Invitation Link & Uniform Error Handling', () => {
    const rawToken = 'test-token-1234567890abcdef1234567890abcdef';
    const tokenHash = hashInvitationToken(rawToken);

    it('returns public view-only details for a valid pending invitation', async () => {
      vi.mocked(prisma.invitation.findUnique).mockResolvedValue({
        id: 'inv-valid',
        idirId,
        phoneNumber: '+251911223344',
        tokenHash,
        status: 'PENDING',
        expiresAt: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000),
        usedAt: null,
        idir: {
          id: idirId,
          name: 'Yeka Michael Idir',
          community: 'Yeka Subcity',
          location: 'Addis Ababa',
          purpose: 'Community mutual aid',
          rules: 'Standard idir rules',
          contributionAmount: 300,
          contributionFrequency: 'MONTHLY',
          status: 'ACTIVE',
        },
      } as any);

      const res = await request(app).get(`/api/v1/invitations/verify?token=${rawToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.idir.name).toBe('Yeka Michael Idir');
      expect(res.body.data.idir.community).toBe('Yeka Subcity');
      expect(res.body.data.idir.purpose).toBe('Community mutual aid');
      // Must not expose internal ledger, bank info, or other members
      expect(res.body.data.idir.members).toBeUndefined();
      expect(res.body.data.idir.balance).toBeUndefined();
    });

    it('returns the exact same generic error message for non-existent token', async () => {
      vi.mocked(prisma.invitation.findUnique).mockResolvedValue(null);

      const res = await request(app).get(`/api/v1/invitations/verify?token=nonexistent`);

      expect(res.status).toBe(400);
      expect(res.body.error.message).toBe('This invitation link is invalid or has expired');
    });

    it('returns the exact same generic error message for expired token', async () => {
      vi.mocked(prisma.invitation.findUnique).mockResolvedValue({
        id: 'inv-expired',
        tokenHash,
        status: 'PENDING',
        expiresAt: new Date(Date.now() - 24 * 60 * 60 * 1000), // Expired yesterday
        usedAt: null,
        idir: { id: idirId, name: 'Yeka Michael Idir' },
      } as any);

      const res = await request(app).get(`/api/v1/invitations/verify?token=${rawToken}`);

      expect(res.status).toBe(400);
      expect(res.body.error.message).toBe('This invitation link is invalid or has expired');
    });

    it('returns the exact same generic error message for revoked token', async () => {
      vi.mocked(prisma.invitation.findUnique).mockResolvedValue({
        id: 'inv-revoked',
        tokenHash,
        status: 'REVOKED',
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        usedAt: null,
        idir: { id: idirId, name: 'Yeka Michael Idir' },
      } as any);

      const res = await request(app).get(`/api/v1/invitations/verify?token=${rawToken}`);

      expect(res.status).toBe(400);
      expect(res.body.error.message).toBe('This invitation link is invalid or has expired');
    });

    it('returns the exact same generic error message for already-used token', async () => {
      vi.mocked(prisma.invitation.findUnique).mockResolvedValue({
        id: 'inv-used',
        tokenHash,
        status: 'ACCEPTED',
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        usedAt: new Date(),
        idir: { id: idirId, name: 'Yeka Michael Idir' },
      } as any);

      const res = await request(app).get(`/api/v1/invitations/verify?token=${rawToken}`);

      expect(res.status).toBe(400);
      expect(res.body.error.message).toBe('This invitation link is invalid or has expired');
    });
  });

  describe('7. Stage 5: Accepting & Declining Invitations', () => {
    const rawToken = 'action-token-1234567890abcdef1234567890abcdef';
    const tokenHash = hashInvitationToken(rawToken);

    it('accepts invitation, creates active membership, and marks invitation ACCEPTED', async () => {
      vi.mocked(prisma.invitation.findUnique).mockResolvedValue({
        id: 'inv-action-1',
        idirId,
        phoneNumber: '+251911000003',
        tokenHash,
        status: 'PENDING',
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        usedAt: null,
        idir: { id: idirId, name: 'Yeka Michael Idir' },
      } as any);

      vi.mocked(prisma.membership.findUnique).mockResolvedValue(null);
      vi.mocked(prisma.membership.count).mockResolvedValue(5);

      const res = await request(app)
        .post('/api/v1/invitations/respond')
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          token: rawToken,
          action: 'ACCEPT',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.action).toBe('ACCEPTED');
      expect(res.body.data.message).toContain('successfully accepted the invitation');

      // Verify membership creation and invitation status update
      expect(prisma.membership.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            idirId,
            userId: memberUserId,
            status: 'ACTIVE',
            role: 'MEMBER',
          }),
        })
      );
      expect(prisma.invitation.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'inv-action-1' },
          data: expect.objectContaining({
            status: 'ACCEPTED',
          }),
        })
      );
    });

    it('declines invitation and marks invitation status DECLINED', async () => {
      vi.mocked(prisma.invitation.findUnique).mockResolvedValue({
        id: 'inv-action-2',
        idirId,
        tokenHash,
        status: 'PENDING',
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        usedAt: null,
        idir: { id: idirId, name: 'Yeka Michael Idir' },
      } as any);

      const res = await request(app)
        .post('/api/v1/invitations/respond')
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          token: rawToken,
          action: 'DECLINE',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.action).toBe('DECLINED');
      expect(prisma.invitation.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'inv-action-2' },
          data: expect.objectContaining({
            status: 'DECLINED',
          }),
        })
      );
    });
  });

  describe('8. Stage 5: Invitation Revocation & Management', () => {
    it('allows creator to revoke a specific invitation', async () => {
      vi.mocked(prisma.invitation.findFirst).mockResolvedValue({
        id: 'inv-to-revoke',
        idirId,
        phoneNumber: '+251911998877',
        status: 'PENDING',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/invitations/inv-to-revoke/revoke`)
        .set('Authorization', `Bearer ${creatorToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.message).toContain('revoked');
      expect(prisma.invitation.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'inv-to-revoke' },
          data: expect.objectContaining({
            status: 'REVOKED',
            revokedById: creatorUserId,
          }),
        })
      );
    });

    it('allows creator to revoke all pending invitations at once', async () => {
      vi.mocked(prisma.invitation.updateMany).mockResolvedValue({ count: 4 } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/invitations/revoke-all`)
        .set('Authorization', `Bearer ${creatorToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.count).toBe(4);
      expect(prisma.invitation.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { idirId, status: 'PENDING' },
          data: expect.objectContaining({
            status: 'REVOKED',
          }),
        })
      );
    });

    it('rejects regular members attempting to revoke invitations with 403 Forbidden', async () => {
      // Regular member has no officer role
      vi.mocked(prisma.membership.findFirst).mockResolvedValue(null);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/invitations/inv-to-revoke/revoke`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('FORBIDDEN');
    });
  });
});

