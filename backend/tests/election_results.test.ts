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
      count: vi.fn(),
      update: vi.fn(),
      updateMany: vi.fn(),
    },
    election: {
      findFirst: vi.fn(),
      update: vi.fn(),
    },
    electionNomination: {
      findFirst: vi.fn(),
      findUnique: vi.fn(),
      findMany: vi.fn(),
    },
    voteReceipt: {
      groupBy: vi.fn(),
      count: vi.fn(),
      deleteMany: vi.fn(),
    },
    ballot: {
      findMany: vi.fn(),
      count: vi.fn(),
      deleteMany: vi.fn(),
    },
    electionResult: {
      upsert: vi.fn(),
      updateMany: vi.fn(),
      findMany: vi.fn(),
    },
    electionDispute: {
      create: vi.fn(),
      findFirst: vi.fn(),
      findMany: vi.fn(),
      count: vi.fn(),
      update: vi.fn(),
    },
    roleTerm: {
      create: vi.fn(),
      updateMany: vi.fn(),
    },
    auditLog: { create: vi.fn() },
    $transaction: vi.fn((callback) => callback(prisma)),
  },
}));

describe('Task 4: Count, Results, Quorum, Disputes, and Certification', () => {
  const idirId = '44444444-4444-4444-4444-444444444444';
  const electionId = 'election-results-uuid-001';

  const chairpersonUserId = 'user-chairperson-uuid';
  const chairpersonMembershipId = 'membership-chairperson-uuid';

  const memberUserId = 'user-member-uuid';
  const memberMembershipId = 'membership-member-uuid';

  const winningCandidateUserId = 'user-winner-uuid';
  const winningCandidateMembershipId = 'membership-winner-uuid';
  const winningNominationId = 'nomination-winner-uuid';
  const winnerNominationId = winningNominationId;

  const runnerUpNominationId = 'nomination-runnerup-uuid';

  let chairpersonToken: string;
  let memberToken: string;

  const mockPastStartDate = new Date(Date.now() - 72 * 60 * 60 * 1000);
  const mockPastEndDate = new Date(Date.now() - 1 * 60 * 60 * 1000); // voting ended 1 hr ago

  const mockElection = {
    id: electionId,
    idirId,
    title: '2026 Leadership Succession Election',
    roles: ['CHAIRPERSON'],
    status: 'VOTING',
    ballotType: 'SECRET',
    votingMethod: 'SIMPLE_MAJORITY',
    quorumPercentage: 50.0,
    disputeWindowHours: 48,
    termLengthMonths: 24,
    handoverDate: null,
    startDate: mockPastStartDate,
    endDate: mockPastEndDate,
    nominations: [
      {
        id: winningNominationId,
        electionId,
        role: 'CHAIRPERSON',
        nomineeMembershipId: winningCandidateMembershipId,
        status: 'ACCEPTED',
        statement: 'Champion of transparency.',
        nomineeMembership: {
          id: winningCandidateMembershipId,
          user: { fullName: 'Abebe Bikila' },
        },
      },
      {
        id: runnerUpNominationId,
        electionId,
        role: 'CHAIRPERSON',
        nomineeMembershipId: 'membership-runnerup-uuid',
        status: 'ACCEPTED',
        statement: 'Modern financial accountability.',
        nomineeMembership: {
          id: 'membership-runnerup-uuid',
          user: { fullName: 'Derartu Tulu' },
        },
      },
    ],
    committeeMembers: [],
    results: [],
    disputes: [],
  };

  beforeEach(() => {
    vi.clearAllMocks();

    chairpersonToken = generateAccessToken({
      userId: chairpersonUserId,
      phoneNumber: '+251911111111',
      isPlatformAdmin: false,
    });

    memberToken = generateAccessToken({
      userId: memberUserId,
      phoneNumber: '+251922222222',
      isPlatformAdmin: false,
    });

    // Mock authenticate user lookup
    vi.mocked(prisma.user.findUnique).mockImplementation((async ({ where }: any) => {
      const id = where.id;
      if (id === chairpersonUserId) {
        return {
          id: chairpersonUserId,
          fullName: 'President Haile',
          phoneNumber: '+251911111111',
          status: 'ACTIVE',
        } as any;
      }
      if (id === memberUserId) {
        return {
          id: memberUserId,
          fullName: 'Regular Member Chala',
          phoneNumber: '+251922222222',
          status: 'ACTIVE',
        } as any;
      }
      return null;
    }) as any);

    // Mock Idir active
    vi.mocked(prisma.idir.findUnique).mockResolvedValue({
      id: idirId,
      name: 'Bole Medhanealem Idir',
      status: 'ACTIVE',
    } as any);

    // Mock memberships
    vi.mocked(prisma.membership.findUnique).mockImplementation((async ({ where }: any) => {
      const idirIdUserId = where.idirId_userId;
      if (idirIdUserId) {
        if (idirIdUserId.userId === chairpersonUserId) {
          return {
            id: chairpersonMembershipId,
            idirId,
            userId: chairpersonUserId,
            role: 'CHAIRPERSON',
            status: 'ACTIVE',
            electionCommitteeMemberships: [],
          } as any;
        }
        if (idirIdUserId.userId === memberUserId) {
          return {
            id: memberMembershipId,
            idirId,
            userId: memberUserId,
            role: 'MEMBER',
            status: 'ACTIVE',
            electionCommitteeMemberships: [],
          } as any;
        }
      }
      return null;
    }) as any);
  });

  describe('1. Automatic Tallying & Quorum Enforcement', () => {
    it('Tallying fails when voter turnout is below required quorum (election invalid)', async () => {
      vi.mocked(prisma.election.findFirst).mockResolvedValue(mockElection as any);

      // Total members = 100, unique voters = 20 -> Turnout = 20% < Quorum (50%)
      vi.mocked(prisma.membership.count).mockResolvedValue(100);
      vi.mocked(prisma.voteReceipt.groupBy).mockResolvedValue(
        new Array(20).fill({ membershipId: 'm-id' }) as any
      );
      vi.mocked(prisma.ballot.count).mockResolvedValue(20);
      vi.mocked(prisma.electionResult.upsert).mockResolvedValue({} as any);
      vi.mocked(prisma.election.update).mockResolvedValue({} as any);
      vi.mocked(prisma.auditLog.create).mockResolvedValue({} as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/tally`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ force: true });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.quorumReached).toBe(false);
      expect(res.body.data.isValid).toBe(false);
      expect(res.body.data.status).toBe('CANCELLED');
      expect(res.body.data.turnoutPercentage).toBe(20);
      expect(res.body.data.quorumPercentage).toBe(50);
      expect(res.body.data.message).toContain('quorum');

      // Verify election marked CANCELLED
      expect(prisma.election.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: electionId },
          data: { status: 'CANCELLED' },
        })
      );
    });

    it('Tallying succeeds when quorum is met and publishes preliminary results with dispute window', async () => {
      vi.mocked(prisma.election.findFirst).mockResolvedValue(mockElection as any);

      // Total members = 100, unique voters = 65 -> Turnout = 65% >= Quorum (50%)
      vi.mocked(prisma.membership.count).mockResolvedValue(100);
      vi.mocked(prisma.voteReceipt.groupBy).mockResolvedValue(
        new Array(65).fill({ membershipId: 'm-id' }) as any
      );

      // Ballots: 45 for Abebe (winningNominationId), 20 for Derartu (runnerUpNominationId)
      const mockBallots = [
        ...new Array(45).fill({ candidateNominationId: winningNominationId }),
        ...new Array(20).fill({ candidateNominationId: runnerUpNominationId }),
      ];
      vi.mocked(prisma.ballot.findMany).mockResolvedValue(mockBallots as any);
      vi.mocked(prisma.electionResult.upsert).mockResolvedValue({} as any);
      vi.mocked(prisma.election.update).mockResolvedValue({} as any);
      vi.mocked(prisma.auditLog.create).mockResolvedValue({} as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/tally`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ force: true });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.quorumReached).toBe(true);
      expect(res.body.data.status).toBe('TALLYING');
      expect(res.body.data.turnoutPercentage).toBe(65);
      expect(res.body.data.disputeWindowEndsAt).toBeDefined();

      const roles = res.body.data.roles;
      expect(roles.length).toBe(1);
      expect(roles[0].role).toBe('CHAIRPERSON');
      expect(roles[0].winnerNominationId).toBe(winningNominationId);
      expect(roles[0].winnerName).toBe('Abebe Bikila');
      expect(roles[0].votesReceived).toBe(45);
      expect(roles[0].totalVotesCast).toBe(65);
      expect(roles[0].isTie).toBe(false);

      // Verify ElectionResult upserted
      expect(prisma.electionResult.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { electionId_role: { electionId, role: 'CHAIRPERSON' } },
          create: expect.objectContaining({
            winnerNominationId,
            quorumReached: true,
            isFinal: false,
          }),
        })
      );
    });

    it('Tallying detects ties and flags role for run-off without declaring winner', async () => {
      vi.mocked(prisma.election.findFirst).mockResolvedValue(mockElection as any);

      // Turnout = 60 >= 50%
      vi.mocked(prisma.membership.count).mockResolvedValue(100);
      vi.mocked(prisma.voteReceipt.groupBy).mockResolvedValue(
        new Array(60).fill({ membershipId: 'm-id' }) as any
      );

      // Exactly 30 votes for Abebe, 30 votes for Derartu (Tie!)
      const mockBallots = [
        ...new Array(30).fill({ candidateNominationId: winningNominationId }),
        ...new Array(30).fill({ candidateNominationId: runnerUpNominationId }),
      ];
      vi.mocked(prisma.ballot.findMany).mockResolvedValue(mockBallots as any);
      vi.mocked(prisma.electionResult.upsert).mockResolvedValue({} as any);
      vi.mocked(prisma.election.update).mockResolvedValue({} as any);
      vi.mocked(prisma.auditLog.create).mockResolvedValue({} as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/tally`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ force: true });

      expect(res.status).toBe(200);
      expect(res.body.data.anyTieDetected).toBe(true);
      const roleResult = res.body.data.roles[0];
      expect(roleResult.isTie).toBe(true);
      expect(roleResult.winnerNominationId).toBeNull();
      expect(roleResult.tiedCandidateIds).toContain(winningNominationId);
      expect(roleResult.tiedCandidateIds).toContain(runnerUpNominationId);
    });
  });

  describe('2. Dispute Window & Dispute Adjudication', () => {
    const activeDisputeWindowEnd = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24h remaining

    it('Active member can file an election dispute during the dispute window', async () => {
      vi.mocked(prisma.election.findFirst).mockResolvedValue({
        ...mockElection,
        status: 'TALLYING',
        results: [
          {
            electionId,
            role: 'CHAIRPERSON',
            winnerNominationId,
            disputeWindowEndsAt: activeDisputeWindowEnd,
          },
        ],
      } as any);

      vi.mocked(prisma.electionDispute.create).mockResolvedValue({
        id: 'dispute-uuid-001',
        electionId,
        filedByMembershipId: memberMembershipId,
        reason: 'Improper campaigning occurred near polling location.',
        status: 'PENDING',
        createdAt: new Date(),
      } as any);

      vi.mocked(prisma.election.update).mockResolvedValue({} as any);
      vi.mocked(prisma.auditLog.create).mockResolvedValue({} as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/disputes`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          reason: 'Improper campaigning occurred near polling location.',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('PENDING');

      // Verify election moved to DISPUTED
      expect(prisma.election.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: electionId },
          data: { status: 'DISPUTED' },
        })
      );
    });

    it('Cannot file dispute after the dispute window has elapsed', async () => {
      const expiredDisputeWindowEnd = new Date(Date.now() - 2 * 60 * 60 * 1000); // 2h ago
      vi.mocked(prisma.election.findFirst).mockResolvedValue({
        ...mockElection,
        status: 'TALLYING',
        results: [
          {
            electionId,
            role: 'CHAIRPERSON',
            winnerNominationId,
            disputeWindowEndsAt: expiredDisputeWindowEnd,
          },
        ],
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/disputes`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          reason: 'Late dispute should not be allowed after window closes.',
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('dispute window for this election has closed');
    });

    it('Committee/Chairperson can resolve a filed dispute and return status to TALLYING', async () => {
      vi.mocked(prisma.electionDispute.findFirst).mockResolvedValue({
        id: 'dispute-uuid-001',
        electionId,
        filedByMembershipId: memberMembershipId,
        status: 'PENDING',
      } as any);

      vi.mocked(prisma.electionDispute.update).mockResolvedValue({
        id: 'dispute-uuid-001',
        status: 'RESOLVED',
        resolution: 'Committee reviewed logs and verified compliance.',
      } as any);

      // No more pending disputes remaining
      vi.mocked(prisma.electionDispute.count).mockResolvedValue(0);
      vi.mocked(prisma.election.update).mockResolvedValue({} as any);
      vi.mocked(prisma.auditLog.create).mockResolvedValue({} as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/disputes/dispute-uuid-001/resolve`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({
          action: 'RESOLVE',
          resolution: 'Committee reviewed logs and verified compliance.',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('RESOLVED');

      // Election returns to TALLYING
      expect(prisma.election.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: electionId },
          data: { status: 'TALLYING' },
        })
      );
    });
  });

  describe('3. Certification & Atomic Leadership Role Handover', () => {
    it('Cannot certify election if there are unresolved disputes', async () => {
      vi.mocked(prisma.election.findFirst).mockResolvedValue({
        ...mockElection,
        status: 'DISPUTED',
        results: [
          {
            electionId,
            role: 'CHAIRPERSON',
            winnerNominationId,
            winnerNomination: { nomineeMembershipId: winningCandidateMembershipId },
            quorumReached: true,
          },
        ],
        disputes: [{ id: 'd-1', status: 'PENDING' }],
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/certify`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send();

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('pending dispute');
    });

    it('Cannot certify election if a role ended in a tie without run-off resolution', async () => {
      vi.mocked(prisma.election.findFirst).mockResolvedValue({
        ...mockElection,
        status: 'TALLYING',
        results: [
          {
            electionId,
            role: 'CHAIRPERSON',
            winnerNominationId: null, // Tie!
            quorumReached: true,
          },
        ],
        disputes: [],
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/certify`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send();

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('Unresolved ties exist');
    });

    it('Done when: Leadership roles ONLY transfer after successful certification', async () => {
      vi.mocked(prisma.election.findFirst).mockResolvedValue({
        ...mockElection,
        status: 'TALLYING',
        results: [
          {
            electionId,
            role: 'CHAIRPERSON',
            winnerNominationId,
            winnerNomination: {
              id: winningNominationId,
              nomineeMembershipId: winningCandidateMembershipId,
            },
            quorumReached: true,
          },
        ],
        disputes: [], // No pending disputes
      } as any);

      vi.mocked(prisma.roleTerm.updateMany).mockResolvedValue({ count: 1 } as any);
      vi.mocked(prisma.membership.updateMany).mockResolvedValue({ count: 1 } as any);
      vi.mocked(prisma.membership.update).mockResolvedValue({} as any);
      vi.mocked(prisma.roleTerm.create).mockResolvedValue({} as any);
      vi.mocked(prisma.electionResult.updateMany).mockResolvedValue({} as any);
      vi.mocked(prisma.election.update).mockResolvedValue({} as any);
      vi.mocked(prisma.auditLog.create).mockResolvedValue({} as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/certify`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send();

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.certified).toBe(true);
      expect(res.body.data.status).toBe('COMPLETED');

      // 1. Existing chairperson demoted back to MEMBER
      expect(prisma.membership.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            idirId,
            role: 'CHAIRPERSON',
            id: { not: winningCandidateMembershipId },
          },
          data: { role: 'MEMBER' },
        })
      );

      // 2. Winner promoted to CHAIRPERSON
      expect(prisma.membership.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: winningCandidateMembershipId },
          data: { role: 'CHAIRPERSON' },
        })
      );

      // 3. New official RoleTerm created
      expect(prisma.roleTerm.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            idirId,
            membershipId: winningCandidateMembershipId,
            role: 'CHAIRPERSON',
            status: 'ACTIVE',
            electionId,
          }),
        })
      );

      // 4. Election finalized to COMPLETED
      expect(prisma.election.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: electionId },
          data: { status: 'COMPLETED' },
        })
      );

      // 5. Results finalized
      expect(prisma.electionResult.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { electionId },
          data: { isFinal: true },
        })
      );
    });
  });

  describe('4. Run-Off Election Triggering', () => {
    it('Triggers run-off voting for tied role by clearing previous ballots and setting new deadline', async () => {
      vi.mocked(prisma.election.findFirst).mockResolvedValue({
        ...mockElection,
        status: 'TALLYING',
        results: [
          {
            electionId,
            role: 'CHAIRPERSON',
            winnerNominationId: null, // Tie
          },
        ],
      } as any);

      vi.mocked(prisma.ballot.deleteMany).mockResolvedValue({ count: 60 } as any);
      vi.mocked(prisma.voteReceipt.deleteMany).mockResolvedValue({ count: 60 } as any);
      vi.mocked(prisma.election.update).mockResolvedValue({} as any);
      vi.mocked(prisma.auditLog.create).mockResolvedValue({} as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/runoff`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({
          role: 'CHAIRPERSON',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.runoffActive).toBe(true);
      expect(res.body.data.role).toBe('CHAIRPERSON');

      // Verify previous ballots and vote receipts cleared for run-off
      expect(prisma.ballot.deleteMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { electionId, role: 'CHAIRPERSON' },
        })
      );
      expect(prisma.voteReceipt.deleteMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { electionId, role: 'CHAIRPERSON' },
        })
      );

      // Verify election reopened to VOTING
      expect(prisma.election.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: electionId },
          data: expect.objectContaining({ status: 'VOTING' }),
        })
      );
    });
  });
});
