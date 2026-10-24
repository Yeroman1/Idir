import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/config/database.js';
import { generateAccessToken } from '../src/shared/utils/jwt.js';

vi.mock('../src/config/database.js', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    idir: { findUnique: vi.fn() },
    membership: {
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      findMany: vi.fn(),
    },
    election: {
      findFirst: vi.fn(),
    },
    electionNomination: {
      findFirst: vi.fn(),
      findMany: vi.fn(),
    },
    voteReceipt: {
      findUnique: vi.fn(),
      findMany: vi.fn(),
      create: vi.fn(),
    },
    ballot: {
      create: vi.fn(),
    },
    auditLog: { create: vi.fn() },
    $transaction: vi.fn((callback) => callback(prisma)),
  },
}));

describe('Task 3: Voting - One Vote Per Role and Anonymity', () => {
  const idirId = '33333333-3333-3333-3333-333333333333';
  const electionId = 'election-voting-uuid-001';

  const voterUserId = 'voter-user-uuid';
  const voterMembershipId = 'membership-voter-uuid';

  let voterToken: string;

  const candidateChairpersonId = 'cand-chair-001';
  const candidateTreasurerId = 'cand-treas-001';

  const electionStartDate = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const electionEndDate = new Date(Date.now() + 48 * 60 * 60 * 1000);

  const mockSecretElection = {
    id: electionId,
    idirId,
    title: 'Idir General Leadership Election 2026',
    roles: ['CHAIRPERSON', 'TREASURER', 'SECRETARY'],
    status: 'VOTING',
    ballotType: 'SECRET',
    votingMethod: 'SIMPLE_MAJORITY',
    startDate: electionStartDate,
    endDate: electionEndDate,
    minMembershipTenureDays: 30,
    committeeMembers: [],
  };

  const mockOpenElection = {
    ...mockSecretElection,
    ballotType: 'OPEN',
  };

  beforeEach(() => {
    vi.clearAllMocks();

    voterToken = generateAccessToken({
      userId: voterUserId,
      phoneNumber: '+251911888888',
      isPlatformAdmin: false,
    });

    // Default mock user lookup for authenticate middleware
    vi.mocked(prisma.user.findUnique).mockImplementation((async ({ where }: any) => {
      const id = where.id;
      if (id === voterUserId) {
        return {
          id: voterUserId,
          fullName: 'Almaz Ayana',
          phoneNumber: '+251911888888',
          status: 'ACTIVE',
          isPlatformAdmin: false,
        } as any;
      }
      return null;
    }) as any);

    // Default mock Idir is ACTIVE
    (prisma.idir.findUnique as any).mockResolvedValue({
      id: idirId,
      name: 'Selam Edir',
      status: 'ACTIVE',
    });

    // Default mock election in voting phase
    (prisma.election.findFirst as any).mockResolvedValue(mockSecretElection);

    // Default audit log
    (prisma.auditLog.create as any).mockResolvedValue({ id: 'audit-log-uuid' });
  });

  describe('Voting Window and Eligibility Enforcement', () => {
    it('rejects vote if voting window has not opened yet', async () => {
      // Election startDate is in future
      (prisma.election.findFirst as any).mockResolvedValue({
        ...mockSecretElection,
        startDate: new Date(Date.now() + 24 * 60 * 60 * 1000),
        endDate: new Date(Date.now() + 48 * 60 * 60 * 1000),
      });

      (prisma.membership.findUnique as any).mockResolvedValue({
        id: voterMembershipId,
        idirId,
        userId: voterUserId,
        status: 'ACTIVE',
        joinedAt: new Date(Date.now() - 100 * 24 * 60 * 60 * 1000),
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({
          role: 'CHAIRPERSON',
          candidateNominationId: candidateChairpersonId,
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('voting window for this election has not opened yet');
    });

    it('rejects vote if voting window has officially closed', async () => {
      // Election endDate is in the past
      (prisma.election.findFirst as any).mockResolvedValue({
        ...mockSecretElection,
        startDate: new Date(Date.now() - 48 * 60 * 60 * 1000),
        endDate: new Date(Date.now() - 24 * 60 * 60 * 1000),
      });

      (prisma.membership.findUnique as any).mockResolvedValue({
        id: voterMembershipId,
        idirId,
        userId: voterUserId,
        status: 'ACTIVE',
        joinedAt: new Date(Date.now() - 100 * 24 * 60 * 60 * 1000),
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({
          role: 'CHAIRPERSON',
          candidateNominationId: candidateChairpersonId,
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('voting window for this election has officially closed');
    });

    it('rejects vote if member has not met the minimum tenure requirement', async () => {
      // Member joined 5 days ago; election requires 30 days
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: voterMembershipId,
        idirId,
        userId: voterUserId,
        status: 'ACTIVE',
        joinedAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000),
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({
          role: 'CHAIRPERSON',
          candidateNominationId: candidateChairpersonId,
        });

      expect(res.status).toBe(403);
      expect(res.body.error.message).toContain('minimum tenure requirement');
    });

    it('rejects vote for a candidate whose nomination status is not ACCEPTED (Done when rule)', async () => {
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: voterMembershipId,
        idirId,
        userId: voterUserId,
        status: 'ACTIVE',
        joinedAt: new Date('2024-01-01T00:00:00Z'),
      });

      // Candidate is PENDING (nominee hasn't accepted)
      (prisma.electionNomination.findFirst as any).mockResolvedValue({
        id: candidateChairpersonId,
        electionId,
        role: 'CHAIRPERSON',
        status: 'PENDING',
        nomineeMembership: { user: { fullName: 'Pending Nominee' } },
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({
          role: 'CHAIRPERSON',
          candidateNominationId: candidateChairpersonId,
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('Only officially accepted candidates on the ballot can receive votes');
    });
  });

  describe('One Vote Per Role & Double-Voting Prevention', () => {
    it('casts vote successfully and stores VoteReceipt separately from Ballot', async () => {
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: voterMembershipId,
        idirId,
        userId: voterUserId,
        status: 'ACTIVE',
        joinedAt: new Date('2024-01-01T00:00:00Z'),
      });

      // Candidate is accepted on ballot
      (prisma.electionNomination.findFirst as any).mockResolvedValue({
        id: candidateChairpersonId,
        electionId,
        role: 'CHAIRPERSON',
        status: 'ACCEPTED',
        nomineeMembership: { user: { fullName: 'Abebe Bikila' } },
      });

      // No previous vote receipt for CHAIRPERSON
      (prisma.voteReceipt.findUnique as any).mockResolvedValue(null);

      (prisma.voteReceipt.create as any).mockResolvedValue({
        id: 'receipt-uuid-001',
        electionId,
        membershipId: voterMembershipId,
        role: 'CHAIRPERSON',
        votedAt: new Date(),
        receiptTokenHash: 'mock-sha256-hash-abc123xyz',
      });

      (prisma.ballot.create as any).mockResolvedValue({
        id: 'ballot-uuid-001',
        electionId,
        role: 'CHAIRPERSON',
        candidateNominationId: candidateChairpersonId,
        voterMembershipId: null, // Anonymity preserved for SECRET ballot!
        castAt: new Date(),
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({
          role: 'CHAIRPERSON',
          candidateNominationId: candidateChairpersonId,
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.receiptTokenHash).toBeDefined();
      expect(res.body.data.role).toBe('CHAIRPERSON');

      // Verify VoteReceipt was created with member ID
      expect(prisma.voteReceipt.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            electionId,
            membershipId: voterMembershipId,
            role: 'CHAIRPERSON',
          }),
        })
      );

      // Verify Ballot was created with voterMembershipId: null (Secret Ballot Anonymity!)
      expect(prisma.ballot.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            electionId,
            role: 'CHAIRPERSON',
            candidateNominationId: candidateChairpersonId,
            voterMembershipId: null,
          }),
        })
      );
    });

    it('strictly prevents double-voting for the same role', async () => {
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: voterMembershipId,
        idirId,
        userId: voterUserId,
        status: 'ACTIVE',
        joinedAt: new Date('2024-01-01T00:00:00Z'),
      });

      (prisma.electionNomination.findFirst as any).mockResolvedValue({
        id: candidateChairpersonId,
        electionId,
        role: 'CHAIRPERSON',
        status: 'ACCEPTED',
      });

      // An existing VoteReceipt already exists!
      (prisma.voteReceipt.findUnique as any).mockResolvedValue({
        id: 'previous-receipt-uuid',
        electionId,
        role: 'CHAIRPERSON',
        membershipId: voterMembershipId,
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({
          role: 'CHAIRPERSON',
          candidateNominationId: candidateChairpersonId,
        });

      expect(res.status).toBe(409);
      expect(res.body.error.message).toContain('already cast a vote for the role of CHAIRPERSON');
      expect(prisma.ballot.create).not.toHaveBeenCalled();
    });

    it('permits voting for a different role even if another role has already been voted for', async () => {
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: voterMembershipId,
        idirId,
        userId: voterUserId,
        status: 'ACTIVE',
        joinedAt: new Date('2024-01-01T00:00:00Z'),
      });

      // Voting for TREASURER
      (prisma.electionNomination.findFirst as any).mockResolvedValue({
        id: candidateTreasurerId,
        electionId,
        role: 'TREASURER',
        status: 'ACCEPTED',
      });

      // No receipt for TREASURER yet
      (prisma.voteReceipt.findUnique as any).mockResolvedValue(null);

      (prisma.voteReceipt.create as any).mockResolvedValue({
        id: 'receipt-uuid-treasurer',
        electionId,
        membershipId: voterMembershipId,
        role: 'TREASURER',
        votedAt: new Date(),
        receiptTokenHash: 'mock-hash-treasurer',
      });

      (prisma.ballot.create as any).mockResolvedValue({
        id: 'ballot-uuid-treasurer',
        electionId,
        role: 'TREASURER',
        candidateNominationId: candidateTreasurerId,
        voterMembershipId: null,
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({
          role: 'TREASURER',
          candidateNominationId: candidateTreasurerId,
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.role).toBe('TREASURER');
    });
  });

  describe('Open Ballot Tracking Support', () => {
    it('records voterMembershipId on Ballot for OPEN ballot elections', async () => {
      (prisma.election.findFirst as any).mockResolvedValue(mockOpenElection);

      (prisma.membership.findUnique as any).mockResolvedValue({
        id: voterMembershipId,
        idirId,
        userId: voterUserId,
        status: 'ACTIVE',
        joinedAt: new Date('2024-01-01T00:00:00Z'),
      });

      (prisma.electionNomination.findFirst as any).mockResolvedValue({
        id: candidateChairpersonId,
        electionId,
        role: 'CHAIRPERSON',
        status: 'ACCEPTED',
      });

      (prisma.voteReceipt.findUnique as any).mockResolvedValue(null);

      (prisma.voteReceipt.create as any).mockResolvedValue({
        id: 'receipt-open-001',
        electionId,
        membershipId: voterMembershipId,
        role: 'CHAIRPERSON',
        votedAt: new Date(),
      });

      (prisma.ballot.create as any).mockResolvedValue({
        id: 'ballot-open-001',
        electionId,
        role: 'CHAIRPERSON',
        candidateNominationId: candidateChairpersonId,
        voterMembershipId: voterMembershipId, // Recorded for OPEN ballots
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({
          role: 'CHAIRPERSON',
          candidateNominationId: candidateChairpersonId,
        });

      expect(res.status).toBe(201);
      expect(prisma.ballot.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            voterMembershipId: voterMembershipId,
          }),
        })
      );
    });
  });

  describe('GET /api/v1/idirs/:idirId/elections/:electionId/voting-status', () => {
    it('returns member voted roles and pending roles', async () => {
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: voterMembershipId,
        idirId,
        userId: voterUserId,
        status: 'ACTIVE',
        joinedAt: new Date('2024-01-01T00:00:00Z'),
      });

      // Member already voted for CHAIRPERSON
      (prisma.voteReceipt.findMany as any).mockResolvedValue([
        {
          id: 'receipt-1',
          role: 'CHAIRPERSON',
          votedAt: new Date(),
          receiptTokenHash: 'hash-1',
        },
      ]);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/elections/${electionId}/voting-status`)
        .set('Authorization', `Bearer ${voterToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.votedRoles).toEqual(['CHAIRPERSON']);
      expect(res.body.data.pendingRoles).toEqual(['TREASURER', 'SECRETARY']);
      expect(res.body.data.canVote).toBe(true);
    });
  });

  describe('GET /api/v1/idirs/:idirId/elections/:electionId/ballot', () => {
    it('returns official ballot with accepted candidates and voter receipts', async () => {
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: voterMembershipId,
        idirId,
        userId: voterUserId,
        status: 'ACTIVE',
      });

      (prisma.electionNomination.findMany as any).mockResolvedValue([
        {
          id: candidateChairpersonId,
          role: 'CHAIRPERSON',
          statement: 'Community development first',
          nomineeMembership: {
            id: 'nom-mem-1',
            memberNumber: 'MBR-101',
            user: { id: 'u-1', fullName: 'Abebe Bikila' },
          },
        },
      ]);

      (prisma.voteReceipt.findMany as any).mockResolvedValue([]);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/elections/${electionId}/ballot`)
        .set('Authorization', `Bearer ${voterToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.ballotByRole.CHAIRPERSON).toHaveLength(1);
      expect(res.body.data.ballotByRole.CHAIRPERSON[0].nomineeMembership.user.fullName).toBe('Abebe Bikila');
    });
  });
});
