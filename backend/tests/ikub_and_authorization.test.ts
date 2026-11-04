import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/config/database.js';
import { generateAccessToken } from '../src/shared/utils/jwt.js';

vi.mock('../src/config/database.js', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    membership: { findUnique: vi.fn(), findFirst: vi.fn() },
    ikubGroup: { findFirst: vi.fn(), findUnique: vi.fn() },
    ikubRound: { findFirst: vi.fn(), findUnique: vi.fn(), update: vi.fn() },
    ikubParticipant: { findFirst: vi.fn(), findUnique: vi.fn(), findMany: vi.fn(), create: vi.fn(), update: vi.fn(), updateMany: vi.fn(), count: vi.fn() },
    ikubPayout: { create: vi.fn() },
    ikubJoinRequest: { findFirst: vi.fn(), create: vi.fn(), update: vi.fn(), upsert: vi.fn() },
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

    vi.mocked(prisma.ikubGroup.findFirst).mockResolvedValue({
      id: groupId,
      idirId,
      winnersPerRound: 1,
      totalRounds: 5,
      contributionAmount: 1000,
    } as any);

    // Mock round that ALREADY has a drawn winner and payout
    vi.mocked(prisma.ikubRound.findFirst).mockResolvedValue({
      id: roundId,
      ikubGroupId: groupId,
      roundNumber: 1,
      status: 'IN_PROGRESS',
      drawnAt: new Date(),
      recipientParticipantId: '00000000-0000-0000-0000-000000000030',
      payouts: [
        {
          id: 'existing-payout-uuid',
          recipientParticipantId: '00000000-0000-0000-0000-000000000030',
          amount: '4000.00',
        },
      ],
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
    expect(res.body.error.message).toMatch(/already (reached the maximum|been recorded)/);
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

  it('prohibits member from submitting join request for another member (IDOR protection)', async () => {
    // Current authenticated member has ID '00000000-0000-0000-0000-000000000011'
    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: '00000000-0000-0000-0000-000000000011',
      idirId,
      userId,
      role: 'MEMBER',
      status: 'ACTIVE',
    } as any);

    // Attempt to pass another valid UUID membership ID in request body
    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/ikub/groups/${groupId}/join`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        membershipId: '00000000-0000-0000-0000-000000000999',
        note: 'Malicious enrollment',
      });

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('FORBIDDEN');
    expect(res.body.error.message).toContain('only enroll your own membership');
  });

  it('rejects join request when Ikub capacity is full', async () => {
    const memberId = '00000000-0000-0000-0000-000000000011';
    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: memberId,
      idirId,
      userId,
      role: 'MEMBER',
      status: 'ACTIVE',
    } as any);

    vi.mocked(prisma.membership.findFirst).mockResolvedValue({
      id: memberId,
      idirId,
      userId,
      role: 'MEMBER',
      status: 'ACTIVE',
      user: { fullName: 'Member Name', phoneNumber: '+251911111111' },
    } as any);

    vi.mocked(prisma.ikubParticipant.findUnique).mockResolvedValue(null);

    // Group with totalRounds = 2, winnersPerRound = 1 -> maxCapacity = 2
    vi.mocked(prisma.ikubGroup.findFirst).mockResolvedValue({
      id: groupId,
      idirId,
      status: 'ACTIVE',
      totalRounds: 2,
      winnersPerRound: 1,
    } as any);

    // Already 2 active participants
    vi.mocked(prisma.ikubParticipant.count).mockResolvedValue(2);

    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/ikub/groups/${groupId}/join`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        note: 'Please let me join',
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('BAD_REQUEST');
    expect(res.body.error.message).toContain('capacity');
  });

  it('rejects payout before lottery draw has occurred (drawnAt is null)', async () => {
    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-uuid-treasurer',
      idirId,
      userId,
      role: 'TREASURER',
      status: 'ACTIVE',
    } as any);

    vi.mocked(prisma.ikubGroup.findFirst).mockResolvedValue({
      id: groupId,
      idirId,
      winnersPerRound: 1,
      totalRounds: 5,
      contributionAmount: 1000,
    } as any);

    // Round with NO draw conducted yet
    vi.mocked(prisma.ikubRound.findFirst).mockResolvedValue({
      id: roundId,
      ikubGroupId: groupId,
      roundNumber: 1,
      status: 'SCHEDULED',
      drawnAt: null,
      recipientParticipantId: null,
      payouts: [],
    } as any);

    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/ikub/groups/${groupId}/payouts`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        roundId,
        recipientParticipantId: '00000000-0000-0000-0000-000000000030',
        amount: 4000,
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('BAD_REQUEST');
    expect(res.body.error.message).toContain('lottery draw has not been conducted');
    expect(prisma.ikubPayout.create).not.toHaveBeenCalled();
  });

  it('rejects payout when recipient is not the drawn winner', async () => {
    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-uuid-treasurer',
      idirId,
      userId,
      role: 'TREASURER',
      status: 'ACTIVE',
    } as any);

    vi.mocked(prisma.ikubGroup.findFirst).mockResolvedValue({
      id: groupId,
      idirId,
      winnersPerRound: 1,
      totalRounds: 5,
      contributionAmount: 1000,
    } as any);

    const drawnWinnerId = '00000000-0000-0000-0000-000000000030';
    const wrongRecipientId = '00000000-0000-0000-0000-000000000099';

    vi.mocked(prisma.ikubRound.findFirst).mockResolvedValue({
      id: roundId,
      ikubGroupId: groupId,
      roundNumber: 1,
      status: 'IN_PROGRESS',
      drawnAt: new Date(),
      recipientParticipantId: drawnWinnerId,
      payouts: [],
    } as any);

    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/ikub/groups/${groupId}/payouts`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        roundId,
        recipientParticipantId: wrongRecipientId,
        amount: 4000,
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('BAD_REQUEST');
    expect(res.body.error.message).toContain('Recipient participant is not the drawn winner');
    expect(prisma.ikubPayout.create).not.toHaveBeenCalled();
  });

  it('enforces payout split share when winnersPerRound > 1', async () => {
    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-uuid-treasurer',
      idirId,
      userId,
      role: 'TREASURER',
      status: 'ACTIVE',
    } as any);

    // Group with 2 winners per round, 1000 ETB per participant
    vi.mocked(prisma.ikubGroup.findFirst).mockResolvedValue({
      id: groupId,
      idirId,
      winnersPerRound: 2,
      totalRounds: 5,
      contributionAmount: 1000,
    } as any);

    const drawnWinnerId = '00000000-0000-0000-0000-000000000030';

    vi.mocked(prisma.ikubRound.findFirst).mockResolvedValue({
      id: roundId,
      ikubGroupId: groupId,
      roundNumber: 1,
      status: 'IN_PROGRESS',
      drawnAt: new Date(),
      recipientParticipantId: drawnWinnerId,
      payouts: [],
    } as any);

    vi.mocked(prisma.ikubParticipant.findFirst).mockResolvedValue({
      id: drawnWinnerId,
      ikubGroupId: groupId,
      status: 'ACTIVE',
      hasWonPayout: false,
    } as any);

    // 10 active participants -> total pot is 10,000 ETB. Max share per winner is 5,000 ETB (50/50 split)
    vi.mocked(prisma.ikubParticipant.count).mockResolvedValue(10);

    // Attempt to disburse 6,000 ETB (more than 5,000 ETB share)
    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/ikub/groups/${groupId}/payouts`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        roundId,
        recipientParticipantId: drawnWinnerId,
        amount: 6000,
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('BAD_REQUEST');
    expect(res.body.error.message).toContain('maximum allowed share of 5000.00 ETB per winner');
    expect(prisma.ikubPayout.create).not.toHaveBeenCalled();
  });

  it('rejects lottery redraw without isRedraw and redrawReason when winner is pending payout', async () => {
    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-uuid-treasurer',
      idirId,
      userId,
      role: 'TREASURER',
      status: 'ACTIVE',
    } as any);

    vi.mocked(prisma.ikubGroup.findFirst).mockResolvedValue({
      id: groupId,
      idirId,
      winnersPerRound: 1,
      totalRounds: 5,
      contributionAmount: 1000,
    } as any);

    const pendingWinnerId = '00000000-0000-0000-0000-000000000030';

    // Round has drawn recipient but no payout recorded yet
    vi.mocked(prisma.ikubRound.findFirst).mockResolvedValue({
      id: roundId,
      ikubGroupId: groupId,
      roundNumber: 1,
      status: 'IN_PROGRESS',
      recipientParticipantId: pendingWinnerId,
      payouts: [],
    } as any);

    // Attempt to redraw without isRedraw: true
    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/ikub/groups/${groupId}/rounds/${roundId}/draw`)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(409);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('CONFLICT');
    expect(res.body.error.message).toContain('already been drawn');
    expect(prisma.ikubRound.update).not.toHaveBeenCalled();
  });

  it('allows audited lottery redraw with isRedraw and redrawReason', async () => {
    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-uuid-treasurer',
      idirId,
      userId,
      role: 'TREASURER',
      status: 'ACTIVE',
    } as any);

    vi.mocked(prisma.ikubGroup.findFirst).mockResolvedValue({
      id: groupId,
      idirId,
      winnersPerRound: 1,
      totalRounds: 5,
      contributionAmount: 1000,
    } as any);

    const previousWinnerId = '00000000-0000-0000-0000-000000000030';
    const newWinnerId = '00000000-0000-0000-0000-000000000031';

    vi.mocked(prisma.ikubRound.findFirst).mockResolvedValue({
      id: roundId,
      ikubGroupId: groupId,
      roundNumber: 1,
      status: 'IN_PROGRESS',
      recipientParticipantId: previousWinnerId,
      payouts: [],
    } as any);

    vi.mocked(prisma.ikubParticipant.findMany).mockResolvedValue([
      {
        id: newWinnerId,
        membershipId: 'membership-uuid-winner-2',
        membership: {
          user: {
            id: 'user-2',
            fullName: 'Abebe Bikila',
            phoneNumber: '+251911223344',
          },
        },
      },
    ] as any);

    vi.mocked(prisma.ikubRound.update).mockResolvedValue({
      id: roundId,
      recipientParticipantId: newWinnerId,
      status: 'IN_PROGRESS',
    } as any);

    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/ikub/groups/${groupId}/rounds/${roundId}/draw`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        isRedraw: true,
        redrawReason: 'Winner moved out of region and declined payout',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.winner.id).toBe(newWinnerId);
    expect(prisma.ikubRound.update).toHaveBeenCalled();
  });

  it('rejects approving join request when Ikub group capacity is full', async () => {
    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-uuid-secretary',
      idirId,
      userId,
      role: 'SECRETARY',
      status: 'ACTIVE',
    } as any);

    const requestId = '00000000-0000-0000-0000-000000000088';

    vi.mocked(prisma.ikubJoinRequest.findFirst).mockResolvedValue({
      id: requestId,
      ikubGroupId: groupId,
      membershipId: 'membership-uuid-applicant',
      status: 'PENDING',
      ikubGroup: {
        id: groupId,
        idirId,
        status: 'ACTIVE',
        totalRounds: 2,
        winnersPerRound: 1,
      },
    } as any);

    vi.mocked(prisma.ikubGroup.findUnique).mockResolvedValue({
      id: groupId,
      idirId,
      status: 'ACTIVE',
      totalRounds: 2,
      winnersPerRound: 1,
    } as any);

    // Group capacity is 2 * 1 = 2; currently 2 participants are already active
    vi.mocked(prisma.ikubParticipant.count).mockResolvedValue(2);

    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/ikub/groups/${groupId}/join-requests/${requestId}/respond`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        status: 'APPROVED',
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('BAD_REQUEST');
    expect(res.body.error.message).toContain('capacity');
    expect(prisma.ikubParticipant.create).not.toHaveBeenCalled();
  });
});
