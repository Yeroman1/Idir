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
    noConfidenceVote: {
      create: vi.fn(),
      findFirst: vi.fn(),
      findMany: vi.fn(),
      update: vi.fn(),
    },
    noConfidenceBallot: {
      create: vi.fn(),
      findUnique: vi.fn(),
    },
    roleTerm: {
      create: vi.fn(),
      findFirst: vi.fn(),
      updateMany: vi.fn(),
    },
    election: {
      create: vi.fn(),
    },
    auditLog: { create: vi.fn() },
    $transaction: vi.fn((callback) => callback(prisma)),
  },
}));

describe('Task 5: Other Leadership Events - No-Confidence & Vacancy Flow', () => {
  const idirId = '55555555-5555-5555-5555-555555555555';
  const chairUserId = 'user-chair-uuid-1';
  const memberUserId = 'user-member-uuid-2';
  const otherMemberUserId = 'user-member-uuid-3';

  const chairMembershipId = '11111111-1111-1111-1111-111111111111';
  const memberMembershipId = '22222222-2222-2222-2222-222222222222';
  const otherMembershipId = '33333333-3333-3333-3333-333333333333';

  let chairToken: string;
  let memberToken: string;

  beforeEach(() => {
    vi.clearAllMocks();

    chairToken = generateAccessToken({
      userId: chairUserId,
      phoneNumber: '+251911111111',
      isPlatformAdmin: false,
    });

    memberToken = generateAccessToken({
      userId: memberUserId,
      phoneNumber: '+251922222222',
      isPlatformAdmin: false,
    });

    // Mock active Idir
    vi.mocked(prisma.idir.findUnique).mockResolvedValue({
      id: idirId,
      name: 'Bole Medhanealem Idir',
      status: 'ACTIVE',
    } as any);

    // Mock default user with ACTIVE status
    vi.mocked(prisma.user.findUnique).mockImplementation((async ({ where }: any) => {
      const id = where.id;
      return {
        id,
        phoneNumber: id === chairUserId ? '+251911111111' : '+251922222222',
        fullName: id === chairUserId ? 'Abebe Chairperson' : 'Chala Member',
        status: 'ACTIVE',
      } as any;
    }) as any);

    // Mock requireIdirRole middleware lookup
    vi.mocked(prisma.membership.findUnique).mockImplementation((async ({ where }: any) => {
      if (where?.idirId_userId) {
        const { userId } = where.idirId_userId;
        if (userId === chairUserId) {
          return {
            id: chairMembershipId,
            idirId,
            userId: chairUserId,
            role: 'CHAIRPERSON',
            status: 'ACTIVE',
          } as any;
        }
        if (userId === memberUserId) {
          return {
            id: memberMembershipId,
            idirId,
            userId: memberUserId,
            role: 'MEMBER',
            status: 'ACTIVE',
          } as any;
        }
      }
      return null;
    }) as any);
  });

  describe('POST /api/v1/idirs/:idirId/elections/no-confidence (Initiate)', () => {
    it('initiates a no-confidence motion against an active officer with configurable threshold', async () => {
      vi.mocked(prisma.membership.findFirst).mockImplementation((async ({ where }: any) => {
        if (where?.userId === memberUserId) {
          return {
            id: memberMembershipId,
            idirId,
            userId: memberUserId,
            status: 'ACTIVE',
            role: 'MEMBER',
          } as any;
        }
        if (where?.id === chairMembershipId) {
          return {
            id: chairMembershipId,
            idirId,
            userId: chairUserId,
            status: 'ACTIVE',
            role: 'CHAIRPERSON',
            user: { fullName: 'Abebe Chairperson', phoneNumber: '+251911111111' },
          } as any;
        }
        return null;
      }) as any);

      vi.mocked(prisma.noConfidenceVote.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.membership.count).mockResolvedValue(50);

      const mockCreatedVote = {
        id: 'nc-vote-uuid-1',
        idirId,
        targetMembershipId: chairMembershipId,
        targetRole: 'CHAIRPERSON',
        initiatedByMembershipId: memberMembershipId,
        reason: 'Repeated financial mismanagement and failure to present quarterly audits',
        thresholdPercentage: 66.67,
        quorumPercentage: 50.0,
        status: 'ACTIVE',
        totalEligibleMembers: 50,
        totalVotesCast: 0,
        supportVotes: 0,
        opposeVotes: 0,
      };
      vi.mocked(prisma.noConfidenceVote.create).mockResolvedValue(mockCreatedVote as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/no-confidence`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          targetMembershipId: chairMembershipId,
          targetRole: 'CHAIRPERSON',
          reason: 'Repeated financial mismanagement and failure to present quarterly audits',
          thresholdPercentage: 66.67,
          quorumPercentage: 50.0,
          durationDays: 7,
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.id).toBe('nc-vote-uuid-1');
      expect(res.body.data.targetRole).toBe('CHAIRPERSON');
      expect(prisma.auditLog.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            action: 'INITIATE_NO_CONFIDENCE',
          }),
        })
      );
    });

    it('rejects no-confidence motion if target does not hold the contested role', async () => {
      vi.mocked(prisma.membership.findFirst).mockImplementation((async ({ where }: any) => {
        if (where?.userId === memberUserId) {
          return {
            id: memberMembershipId,
            idirId,
            userId: memberUserId,
            status: 'ACTIVE',
            role: 'MEMBER',
          } as any;
        }
        if (where?.id === otherMembershipId) {
          return {
            id: otherMembershipId,
            idirId,
            userId: otherMemberUserId,
            status: 'ACTIVE',
            role: 'MEMBER', // Not chairperson!
            user: { fullName: 'Regular Member' },
          } as any;
        }
        return null;
      }) as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/no-confidence`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          targetMembershipId: otherMembershipId,
          targetRole: 'CHAIRPERSON',
          reason: 'Valid grounds describing why removal is necessary',
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('does not currently hold the leadership role');
    });

    it('rejects if an officer files no-confidence against themselves', async () => {
      vi.mocked(prisma.membership.findFirst).mockImplementation((async ({ where }: any) => {
        if (where?.userId === chairUserId) {
          return {
            id: chairMembershipId,
            idirId,
            userId: chairUserId,
            status: 'ACTIVE',
            role: 'CHAIRPERSON',
          } as any;
        }
        return null;
      }) as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/no-confidence`)
        .set('Authorization', `Bearer ${chairToken}`)
        .send({
          targetMembershipId: chairMembershipId,
          targetRole: 'CHAIRPERSON',
          reason: 'Valid grounds describing reasons for no confidence',
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('cannot file a no-confidence motion against themselves');
    });

    it('rejects if another active no-confidence vote is already underway for that role', async () => {
      vi.mocked(prisma.membership.findFirst).mockImplementation((async ({ where }: any) => {
        if (where?.userId === memberUserId) {
          return {
            id: memberMembershipId,
            idirId,
            userId: memberUserId,
            status: 'ACTIVE',
            role: 'MEMBER',
          } as any;
        }
        if (where?.id === chairMembershipId) {
          return {
            id: chairMembershipId,
            idirId,
            userId: chairUserId,
            status: 'ACTIVE',
            role: 'CHAIRPERSON',
            user: { fullName: 'Abebe Chairperson' },
          } as any;
        }
        return null;
      }) as any);

      vi.mocked(prisma.noConfidenceVote.findFirst).mockResolvedValue({
        id: 'existing-vote-id',
        status: 'ACTIVE',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/no-confidence`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          targetMembershipId: chairMembershipId,
          targetRole: 'CHAIRPERSON',
          reason: 'Valid grounds describing reasons for no confidence',
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('already active for the position');
    });
  });

  describe('POST /api/v1/idirs/:idirId/elections/no-confidence/:voteId/vote (Cast Ballot)', () => {
    it('casts a SUPPORT or OPPOSE ballot successfully', async () => {
      vi.mocked(prisma.membership.findFirst).mockResolvedValue({
        id: memberMembershipId,
        idirId,
        userId: memberUserId,
        status: 'ACTIVE',
      } as any);

      const futureDate = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000);
      vi.mocked(prisma.noConfidenceVote.findFirst).mockResolvedValue({
        id: 'nc-vote-1',
        idirId,
        status: 'ACTIVE',
        endDate: futureDate,
        totalVotesCast: 10,
        supportVotes: 6,
        opposeVotes: 4,
      } as any);

      vi.mocked(prisma.noConfidenceBallot.findUnique).mockResolvedValue(null);

      vi.mocked(prisma.noConfidenceVote.update).mockResolvedValue({
        id: 'nc-vote-1',
        status: 'ACTIVE',
        totalVotesCast: 11,
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/no-confidence/nc-vote-1/vote`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({ choice: 'SUPPORT' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.totalVotesCast).toBe(11);
      expect(res.body.data.choiceRecorded).toBe('SUPPORT');
      expect(prisma.noConfidenceBallot.create).toHaveBeenCalledWith({
        data: {
          voteId: 'nc-vote-1',
          voterMembershipId: memberMembershipId,
          choice: 'SUPPORT',
        },
      });
    });

    it('prevents double voting on a no-confidence motion', async () => {
      vi.mocked(prisma.membership.findFirst).mockResolvedValue({
        id: memberMembershipId,
        idirId,
        userId: memberUserId,
        status: 'ACTIVE',
      } as any);

      const futureDate = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000);
      vi.mocked(prisma.noConfidenceVote.findFirst).mockResolvedValue({
        id: 'nc-vote-1',
        idirId,
        status: 'ACTIVE',
        endDate: futureDate,
      } as any);

      vi.mocked(prisma.noConfidenceBallot.findUnique).mockResolvedValue({
        id: 'existing-ballot-id',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/no-confidence/nc-vote-1/vote`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({ choice: 'OPPOSE' });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('already cast your ballot');
    });
  });

  describe('POST /api/v1/idirs/:idirId/elections/no-confidence/:voteId/resolve (Tally & Removal)', () => {
    it('demotes the officer, vacates the role, and marks role term terminated when threshold and quorum are met', async () => {
      vi.mocked(prisma.membership.findFirst).mockResolvedValue({
        id: memberMembershipId,
        idirId,
        userId: memberUserId,
        status: 'ACTIVE',
      } as any);

      vi.mocked(prisma.noConfidenceVote.findFirst).mockResolvedValue({
        id: 'nc-vote-pass',
        idirId,
        targetMembershipId: chairMembershipId,
        targetRole: 'CHAIRPERSON',
        status: 'ACTIVE',
        thresholdPercentage: 66.67,
        quorumPercentage: 50.0,
        totalEligibleMembers: 40,
        totalVotesCast: 30,
        supportVotes: 24,
        opposeVotes: 6,
        endDate: new Date(Date.now() - 1000),
      } as any);

      vi.mocked(prisma.noConfidenceVote.update).mockResolvedValue({
        id: 'nc-vote-pass',
        status: 'PASSED',
        targetMembership: { user: { fullName: 'Demoted Chairperson' } },
        initiatedByMembership: { user: { fullName: 'Filer Member' } },
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/no-confidence/nc-vote-pass/resolve`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({ force: true });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.result.passed).toBe(true);
      expect(res.body.data.result.finalStatus).toBe('PASSED');
      expect(res.body.data.result.roleVacated).toBe(true);

      expect(prisma.membership.update).toHaveBeenCalledWith({
        where: { id: chairMembershipId },
        data: { role: 'MEMBER' },
      });

      expect(prisma.roleTerm.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            membershipId: chairMembershipId,
            role: 'CHAIRPERSON',
            status: 'ACTIVE',
          }),
          data: expect.objectContaining({
            status: 'TERMINATED_NO_CONFIDENCE',
          }),
        })
      );
    });

    it('fails motion when voter turnout is below quorum, retaining officer role', async () => {
      vi.mocked(prisma.membership.findFirst).mockResolvedValue({
        id: memberMembershipId,
        idirId,
        userId: memberUserId,
        status: 'ACTIVE',
      } as any);

      vi.mocked(prisma.noConfidenceVote.findFirst).mockResolvedValue({
        id: 'nc-vote-no-quorum',
        idirId,
        targetMembershipId: chairMembershipId,
        targetRole: 'CHAIRPERSON',
        status: 'ACTIVE',
        thresholdPercentage: 66.67,
        quorumPercentage: 50.0,
        totalEligibleMembers: 100,
        totalVotesCast: 20,
        supportVotes: 18,
        opposeVotes: 2,
        endDate: new Date(Date.now() - 1000),
      } as any);

      vi.mocked(prisma.noConfidenceVote.update).mockResolvedValue({
        id: 'nc-vote-no-quorum',
        status: 'FAILED_NO_QUORUM',
        targetMembership: { user: { fullName: 'Chairperson' } },
        initiatedByMembership: { user: { fullName: 'Filer' } },
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/no-confidence/nc-vote-no-quorum/resolve`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({ force: true });

      expect(res.status).toBe(200);
      expect(res.body.data.result.finalStatus).toBe('FAILED_NO_QUORUM');
      expect(res.body.data.result.passed).toBe(false);
      expect(res.body.data.result.roleVacated).toBe(false);
      expect(prisma.membership.update).not.toHaveBeenCalled();
    });

    it('fails motion when support percentage is below required threshold', async () => {
      vi.mocked(prisma.membership.findFirst).mockResolvedValue({
        id: memberMembershipId,
        idirId,
        userId: memberUserId,
        status: 'ACTIVE',
      } as any);

      vi.mocked(prisma.noConfidenceVote.findFirst).mockResolvedValue({
        id: 'nc-vote-below-threshold',
        idirId,
        targetMembershipId: chairMembershipId,
        targetRole: 'CHAIRPERSON',
        status: 'ACTIVE',
        thresholdPercentage: 66.67,
        quorumPercentage: 50.0,
        totalEligibleMembers: 20,
        totalVotesCast: 15,
        supportVotes: 8,
        opposeVotes: 7,
        endDate: new Date(Date.now() - 1000),
      } as any);

      vi.mocked(prisma.noConfidenceVote.update).mockResolvedValue({
        id: 'nc-vote-below-threshold',
        status: 'FAILED',
        targetMembership: { user: { fullName: 'Chairperson' } },
        initiatedByMembership: { user: { fullName: 'Filer' } },
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/no-confidence/nc-vote-below-threshold/resolve`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({ force: true });

      expect(res.status).toBe(200);
      expect(res.body.data.result.finalStatus).toBe('FAILED');
      expect(res.body.data.result.passed).toBe(false);
      expect(res.body.data.result.roleVacated).toBe(false);
      expect(prisma.membership.update).not.toHaveBeenCalled();
    });
  });

  describe('GET /api/v1/idirs/:idirId/elections/vacancies/status', () => {
    it('accurately lists institutional roles and flags VACANT, INTERIM, or OCCUPIED', async () => {
      vi.mocked(prisma.membership.findFirst).mockImplementation((async ({ where }: any) => {
        if (where?.userId === memberUserId) {
          return {
            id: memberMembershipId,
            idirId,
            userId: memberUserId,
            status: 'ACTIVE',
          } as any;
        }
        if (where?.role === 'CHAIRPERSON') {
          return {
            id: chairMembershipId,
            role: 'CHAIRPERSON',
            status: 'ACTIVE',
            user: { id: chairUserId, fullName: 'Abebe Chairperson', phoneNumber: '+251911111111' },
            memberNumber: 'BM-001',
          } as any;
        }
        if (where?.role === 'SECRETARY') {
          return {
            id: otherMembershipId,
            role: 'SECRETARY',
            status: 'ACTIVE',
            user: { id: otherMemberUserId, fullName: 'Interim Secretary', phoneNumber: '+251933333333' },
            memberNumber: 'BM-005',
          } as any;
        }
        return null; // TREASURER and AUDITOR vacant
      }) as any);

      vi.mocked(prisma.roleTerm.findFirst).mockImplementation((async ({ where }: any) => {
        if (where?.role === 'CHAIRPERSON') {
          return {
            startDate: new Date('2025-01-01'),
            endDate: new Date('2027-01-01'),
            status: 'ACTIVE',
          } as any;
        }
        if (where?.role === 'SECRETARY') {
          return {
            startDate: new Date('2026-06-01'),
            endDate: new Date('2026-12-01'),
            status: 'INTERIM',
          } as any;
        }
        return null;
      }) as any);

      vi.mocked(prisma.noConfidenceVote.findFirst).mockResolvedValue(null);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/elections/vacancies/status`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      const vacancies = res.body.data;
      expect(vacancies).toHaveLength(4);

      const chair = vacancies.find((v: any) => v.role === 'CHAIRPERSON');
      expect(chair.status).toBe('OCCUPIED');
      expect(chair.currentHolder.fullName).toBe('Abebe Chairperson');

      const treasurer = vacancies.find((v: any) => v.role === 'TREASURER');
      expect(treasurer.status).toBe('VACANT');
      expect(treasurer.currentHolder).toBeNull();

      const secretary = vacancies.find((v: any) => v.role === 'SECRETARY');
      expect(secretary.status).toBe('INTERIM');
      expect(secretary.currentHolder.fullName).toBe('Interim Secretary');

      const auditor = vacancies.find((v: any) => v.role === 'AUDITOR');
      expect(auditor.status).toBe('VACANT');
    });
  });

  describe('POST /api/v1/idirs/:idirId/elections/vacancies/appoint (Temporary Appointment)', () => {
    it('allows chairperson to appoint an active member to an interim role', async () => {
      vi.mocked(prisma.membership.findFirst).mockImplementation((async ({ where }: any) => {
        if (where?.userId === chairUserId) {
          return {
            id: chairMembershipId,
            idirId,
            userId: chairUserId,
            role: 'CHAIRPERSON',
            status: 'ACTIVE',
          } as any;
        }
        if (where?.id === otherMembershipId) {
          return {
            id: otherMembershipId,
            idirId,
            userId: otherMemberUserId,
            role: 'MEMBER',
            status: 'ACTIVE',
            user: { fullName: 'New Interim Treasurer' },
          } as any;
        }
        return null;
      }) as any);

      vi.mocked(prisma.membership.update).mockResolvedValue({
        id: otherMembershipId,
        role: 'TREASURER',
        user: { fullName: 'New Interim Treasurer' },
      } as any);

      vi.mocked(prisma.roleTerm.create).mockResolvedValue({
        id: 'term-interim-1',
        idirId,
        membershipId: otherMembershipId,
        role: 'TREASURER',
        status: 'INTERIM',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/vacancies/appoint`)
        .set('Authorization', `Bearer ${chairToken}`)
        .send({
          vacantRole: 'TREASURER',
          appointeeMembershipId: otherMembershipId,
          reason: 'Appointing interim treasurer until next general by-election',
          termMonths: 6,
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.appointee.role).toBe('TREASURER');
      expect(res.body.data.term.status).toBe('INTERIM');
      expect(prisma.auditLog.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            action: 'TEMPORARY_APPOINTMENT',
          }),
        })
      );
    });

    it('rejects interim appointment if actor is a regular member', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/vacancies/appoint`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          vacantRole: 'TREASURER',
          appointeeMembershipId: otherMembershipId,
        });

      expect(res.status).toBe(403);
    });
  });

  describe('POST /api/v1/idirs/:idirId/elections/vacancies/by-election (Special By-Election)', () => {
    it('creates an expedited by-election for a vacant role', async () => {
      vi.mocked(prisma.membership.findFirst).mockResolvedValue({
        id: chairMembershipId,
        idirId,
        userId: chairUserId,
        role: 'CHAIRPERSON',
        status: 'ACTIVE',
      } as any);

      vi.mocked(prisma.membership.findMany).mockResolvedValue([
        { id: otherMembershipId, idirId, status: 'ACTIVE' },
      ] as any);

      const now = new Date();
      const future = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000);

      vi.mocked(prisma.election.create).mockResolvedValue({
        id: 'by-election-1',
        idirId,
        title: 'By-Election for AUDITOR',
        roles: ['AUDITOR'],
        status: 'DRAFT',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/vacancies/by-election`)
        .set('Authorization', `Bearer ${chairToken}`)
        .send({
          vacantRole: 'AUDITOR',
          startDate: now.toISOString(),
          endDate: future.toISOString(),
          committeeMemberIds: [otherMembershipId],
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.id).toBe('by-election-1');
      expect(res.body.data.roles).toContain('AUDITOR');
      expect(prisma.auditLog.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            action: 'CREATE_BY_ELECTION',
          }),
        })
      );
    });
  });
});
