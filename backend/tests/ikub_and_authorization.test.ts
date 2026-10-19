import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/config/database.js';
import { generateAccessToken } from '../src/shared/utils/jwt.js';

vi.mock('../src/config/database.js', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    membership: { findUnique: vi.fn(), findFirst: vi.fn() },
    ikubGroup: { findFirst: vi.fn() },
    ikubRound: { findFirst: vi.fn(), update: vi.fn() },
    ikubParticipant: { findFirst: vi.fn(), update: vi.fn() },
    ikubPayout: { create: vi.fn() },
    assistanceCase: { findFirst: vi.fn() },
    auditLog: { create: vi.fn() },
    $transaction: vi.fn((callback) => callback(prisma)),
  },
}));

describe('Ikub Safeguards & Role-Based Authorization Tests', () => {
  const userId = 'user-uuid-1';
  const idirId = '00000000-0000-0000-0000-000000000001';
  const groupId = '00000000-0000-0000-0000-000000000010';
  const roundId = '00000000-0000-0000-0000-000000000020';
  let token: string;

  beforeEach(() => {
    vi.clearAllMocks();
    token = generateAccessToken({
      userId,
      phoneNumber: '+251911555555',
      isPlatformAdmin: false,
    });

    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: userId,
      phoneNumber: '+251911555555',
      fullName: 'Ordinary Member User',
      status: 'ACTIVE',
      isPlatformAdmin: false,
      preferredLanguage: 'am',
    } as any);
  });

  it('rejects access when user is not a member of the target Idir (Cross-Idir isolation)', async () => {
    // Return null membership
    vi.mocked(prisma.membership.findUnique).mockResolvedValue(null);

    const res = await request(app)
      .get(`/api/v1/idirs/${idirId}/members`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('FORBIDDEN');
    expect(res.body.error.message).toContain('not an active member');
  });

  it('prohibits ordinary MEMBER from recording expenses (Role enforcement)', async () => {
    // Ordinary MEMBER role
    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-uuid-member',
      idirId,
      userId,
      role: 'MEMBER',
      status: 'ACTIVE',
    } as any);

    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/expenses`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        amount: 500,
        description: 'Tent hire',
      });

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('strictly prevents duplicate Ikub payout for the same round', async () => {
    // Set user as TREASURER so they have permission to execute payout
    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-uuid-treasurer',
      idirId,
      userId,
      role: 'TREASURER',
      status: 'ACTIVE',
    } as any);

    // Mock round that ALREADY has a payout
    vi.mocked(prisma.ikubRound.findFirst).mockResolvedValue({
      id: roundId,
      ikubGroupId: groupId,
      roundNumber: 1,
      status: 'COMPLETED',
      payout: {
        id: 'existing-payout-uuid',
        amount: '4000.00',
      },
    } as any);

    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/ikub/groups/${groupId}/payouts`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        roundId,
        recipientParticipantId: '00000000-0000-0000-0000-000000000030',
        amount: 4000,
      });

    expect(res.status).toBe(409);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('CONFLICT');
    expect(res.body.error.message).toContain('already been paid out');
    expect(prisma.ikubPayout.create).not.toHaveBeenCalled();
  });

  it('enforces confidentiality on assistance case details for non-privileged members', async () => {
    // Ordinary MEMBER
    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-uuid-member',
      idirId,
      userId,
      role: 'MEMBER',
      status: 'ACTIVE',
    } as any);

    // Confidential case belonging to another member
    vi.mocked(prisma.assistanceCase.findFirst).mockResolvedValue({
      id: 'case-uuid-confidential',
      idirId,
      title: 'Confidential Illness Claim',
      isConfidential: true,
      membership: {
        userId: 'different-user-uuid',
      },
    } as any);

    const res = await request(app)
      .get(`/api/v1/idirs/${idirId}/assistance/cases/case-uuid-confidential`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('FORBIDDEN');
    expect(res.body.error.message).toContain('confidential');
  });
});
