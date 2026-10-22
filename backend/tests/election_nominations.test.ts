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
      create: vi.fn(),
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      findMany: vi.fn(),
      update: vi.fn(),
      upsert: vi.fn(),
    },
    auditLog: { create: vi.fn() },
    $transaction: vi.fn((callback) => callback(prisma)),
  },
}));

describe('Task 2: Nominations and Candidate Pages', () => {
  const idirId = '22222222-2222-2222-2222-222222222222';
  const electionId = 'election-uuid-001';

  const memberAUserId = 'member-a-uuid';
  const memberAMembershipId = 'membership-a-uuid';

  const memberBUserId = 'member-b-uuid';
  const memberBMembershipId = 'membership-b-uuid';

  const committeeUserId = 'committee-user-uuid';
  const committeeMembershipId = 'membership-committee-uuid';

  let memberAToken: string;
  let memberBToken: string;
  let committeeToken: string;

  const mockActiveElection = {
    id: electionId,
    idirId,
    title: 'Idir Leadership Election 2026',
    roles: ['CHAIRPERSON', 'TREASURER', 'SECRETARY'],
    status: 'NOMINATION',
    startDate: new Date('2026-11-01T08:00:00Z'),
    endDate: new Date('2026-11-03T18:00:00Z'),
    nominationStartDate: new Date('2026-10-20T08:00:00Z'),
    nominationEndDate: new Date('2026-10-31T18:00:00Z'),
    termLengthMonths: 24,
    minMembershipTenureDays: 30,
    committeeMembers: [{ membershipId: committeeMembershipId }],
  };

  beforeEach(() => {
    vi.clearAllMocks();

    memberAToken = generateAccessToken({
      userId: memberAUserId,
      phoneNumber: '+251911111111',
      isPlatformAdmin: false,
    });

    memberBToken = generateAccessToken({
      userId: memberBUserId,
      phoneNumber: '+251922222222',
      isPlatformAdmin: false,
    });

    committeeToken = generateAccessToken({
      userId: committeeUserId,
      phoneNumber: '+251933333333',
      isPlatformAdmin: false,
    });

    // Default mock user lookup for authenticate middleware
    vi.mocked(prisma.user.findUnique).mockImplementation(async ({ where }: any) => {
      const id = where.id;
      return {
        id,
        fullName: 'Test User',
        phoneNumber: '+251911000000',
        email: null,
        faydaId: 'FAYDA-VERIFIED',
        status: 'ACTIVE',
        isPlatformAdmin: false,
        preferredLanguage: 'am',
      } as any;
    });

    // Default mock: Idir is ACTIVE
    (prisma.idir.findUnique as any).mockResolvedValue({
      id: idirId,
      status: 'ACTIVE',
      name: 'Selam Edir',
    });

    // Default mock: Election is in nomination
    (prisma.election.findFirst as any).mockResolvedValue(mockActiveElection);

    // Default audit log
    (prisma.auditLog.create as any).mockResolvedValue({ id: 'audit-log-uuid' });
  });

  describe('POST /api/v1/idirs/:idirId/elections/:electionId/nominations', () => {
    it('allows a member to self-nominate with automatic ACCEPTED status and short statement', async () => {
      // Actor is member A
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: memberAMembershipId,
        idirId,
        userId: memberAUserId,
        status: 'ACTIVE',
        role: 'MEMBER',
      });

      // Nominee is member A (self)
      (prisma.membership.findFirst as any).mockResolvedValue({
        id: memberAMembershipId,
        idirId,
        userId: memberAUserId,
        status: 'ACTIVE',
        joinedAt: new Date('2025-01-01T00:00:00Z'), // well past 30 days
        user: { id: memberAUserId, fullName: 'Abebe Bikila', phoneNumber: '+251911111111' },
      });

      // No existing nomination
      (prisma.electionNomination.findUnique as any).mockResolvedValue(null);

      // Upsert returns accepted nomination
      const createdNomination = {
        id: 'nomination-self-001',
        electionId,
        role: 'CHAIRPERSON',
        nomineeMembershipId: memberAMembershipId,
        nominatedByMembershipId: memberAMembershipId,
        statement: 'I pledge transparent financial reports and community support.',
        status: 'ACCEPTED',
        acceptedAt: new Date(),
        nomineeMembership: {
          id: memberAMembershipId,
          memberNumber: 'MBR-001',
          user: { id: memberAUserId, fullName: 'Abebe Bikila', phoneNumber: '+251911111111' },
        },
        nominatedByMembership: {
          id: memberAMembershipId,
          memberNumber: 'MBR-001',
          user: { id: memberAUserId, fullName: 'Abebe Bikila' },
        },
      };
      (prisma.electionNomination.upsert as any).mockResolvedValue(createdNomination);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations`)
        .set('Authorization', `Bearer ${memberAToken}`)
        .send({
          role: 'CHAIRPERSON',
          nomineeMembershipId: memberAMembershipId,
          statement: 'I pledge transparent financial reports and community support.',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('ACCEPTED');
      expect(res.body.message).toContain('self-nomination registered and accepted');
      expect(prisma.electionNomination.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          create: expect.objectContaining({
            status: 'ACCEPTED',
            role: 'CHAIRPERSON',
          }),
        })
      );
    });

    it('allows a member to nominate another member with initial PENDING status', async () => {
      // Actor is member A
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: memberAMembershipId,
        idirId,
        userId: memberAUserId,
        status: 'ACTIVE',
        role: 'MEMBER',
      });

      // Nominee is member B
      (prisma.membership.findFirst as any).mockResolvedValue({
        id: memberBMembershipId,
        idirId,
        userId: memberBUserId,
        status: 'ACTIVE',
        joinedAt: new Date('2025-01-01T00:00:00Z'),
        user: { id: memberBUserId, fullName: 'Bethlehem Tilahun', phoneNumber: '+251922222222' },
      });

      (prisma.electionNomination.findUnique as any).mockResolvedValue(null);

      const pendingNomination = {
        id: 'nomination-pending-001',
        electionId,
        role: 'TREASURER',
        nomineeMembershipId: memberBMembershipId,
        nominatedByMembershipId: memberAMembershipId,
        statement: null,
        status: 'PENDING',
        acceptedAt: null,
        nomineeMembership: {
          id: memberBMembershipId,
          memberNumber: 'MBR-002',
          user: { id: memberBUserId, fullName: 'Bethlehem Tilahun', phoneNumber: '+251922222222' },
        },
        nominatedByMembership: {
          id: memberAMembershipId,
          memberNumber: 'MBR-001',
          user: { id: memberAUserId, fullName: 'Abebe Bikila' },
        },
      };
      (prisma.electionNomination.upsert as any).mockResolvedValue(pendingNomination);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations`)
        .set('Authorization', `Bearer ${memberAToken}`)
        .send({
          role: 'TREASURER',
          nomineeMembershipId: memberBMembershipId,
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('PENDING');
      expect(res.body.message).toContain('pending nominee acceptance');
      expect(prisma.electionNomination.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          create: expect.objectContaining({
            status: 'PENDING',
            role: 'TREASURER',
          }),
        })
      );
    });

    it('rejects nomination if nominee is a member of the neutral election committee', async () => {
      // Actor is member A
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: memberAMembershipId,
        idirId,
        userId: memberAUserId,
        status: 'ACTIVE',
        role: 'MEMBER',
      });

      // Nominee is the committee member
      (prisma.membership.findFirst as any).mockResolvedValue({
        id: committeeMembershipId,
        idirId,
        userId: committeeUserId,
        status: 'ACTIVE',
        joinedAt: new Date('2024-01-01T00:00:00Z'),
        user: { id: committeeUserId, fullName: 'Chala Committee', phoneNumber: '+251933333333' },
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations`)
        .set('Authorization', `Bearer ${memberAToken}`)
        .send({
          role: 'SECRETARY',
          nomineeMembershipId: committeeMembershipId,
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('neutral election committee');
    });

    it('rejects nomination if nominee does not fulfill the minimum tenure requirement', async () => {
      // Actor is member A
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: memberAMembershipId,
        idirId,
        userId: memberAUserId,
        status: 'ACTIVE',
        role: 'MEMBER',
      });

      // Nominee joined yesterday (election requires 30 days)
      (prisma.membership.findFirst as any).mockResolvedValue({
        id: memberBMembershipId,
        idirId,
        userId: memberBUserId,
        status: 'ACTIVE',
        joinedAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000),
        user: { id: memberBUserId, fullName: 'Bethlehem Tilahun', phoneNumber: '+251922222222' },
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations`)
        .set('Authorization', `Bearer ${memberAToken}`)
        .send({
          role: 'TREASURER',
          nomineeMembershipId: memberBMembershipId,
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('minimum tenure requirement');
    });

    it('rejects nomination for a role that is not open in this election', async () => {
      // Actor is member A
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: memberAMembershipId,
        idirId,
        userId: memberAUserId,
        status: 'ACTIVE',
        role: 'MEMBER',
      });

      // Election only opened CHAIRPERSON, TREASURER, SECRETARY.
      // Trying to nominate for AUDITOR
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations`)
        .set('Authorization', `Bearer ${memberAToken}`)
        .send({
          role: 'AUDITOR',
          nomineeMembershipId: memberAMembershipId,
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain("role 'AUDITOR' is not open for election");
    });

    it('rejects duplicate active/pending nomination for the same role', async () => {
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: memberAMembershipId,
        idirId,
        userId: memberAUserId,
        status: 'ACTIVE',
        role: 'MEMBER',
      });

      (prisma.membership.findFirst as any).mockResolvedValue({
        id: memberBMembershipId,
        idirId,
        userId: memberBUserId,
        status: 'ACTIVE',
        joinedAt: new Date('2024-01-01T00:00:00Z'),
        user: { id: memberBUserId, fullName: 'Bethlehem Tilahun', phoneNumber: '+251922222222' },
      });

      (prisma.electionNomination.findUnique as any).mockResolvedValue({
        id: 'existing-nom-id',
        status: 'PENDING',
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations`)
        .set('Authorization', `Bearer ${memberAToken}`)
        .send({
          role: 'TREASURER',
          nomineeMembershipId: memberBMembershipId,
        });

      expect(res.status).toBe(409);
      expect(res.body.error.message).toContain('already has an active or pending nomination');
    });
  });

  describe('POST /api/v1/idirs/:idirId/elections/:electionId/nominations/:nominationId/respond', () => {
    it('allows nominated member to accept nomination and provide a short candidate statement', async () => {
      const nominationId = 'nomination-pending-001';

      (prisma.electionNomination.findFirst as any).mockResolvedValue({
        id: nominationId,
        electionId,
        role: 'TREASURER',
        status: 'PENDING',
        nomineeMembership: {
          id: memberBMembershipId,
          userId: memberBUserId, // Matches memberBToken
          user: { fullName: 'Bethlehem Tilahun' },
        },
      });

      (prisma.electionNomination.update as any).mockResolvedValue({
        id: nominationId,
        role: 'TREASURER',
        status: 'ACCEPTED',
        statement: 'Experienced accountant ready to serve our community.',
        acceptedAt: new Date(),
        declinedAt: null,
        nomineeMembership: {
          id: memberBMembershipId,
          memberNumber: 'MBR-002',
          user: { id: memberBUserId, fullName: 'Bethlehem Tilahun' },
        },
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations/${nominationId}/respond`)
        .set('Authorization', `Bearer ${memberBToken}`)
        .send({
          action: 'ACCEPT',
          statement: 'Experienced accountant ready to serve our community.',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('ACCEPTED');
      expect(res.body.message).toContain('will appear on the ballot');
      expect(prisma.electionNomination.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: nominationId },
          data: expect.objectContaining({
            status: 'ACCEPTED',
            statement: 'Experienced accountant ready to serve our community.',
          }),
        })
      );
    });

    it('allows nominated member to decline nomination', async () => {
      const nominationId = 'nomination-pending-002';

      (prisma.electionNomination.findFirst as any).mockResolvedValue({
        id: nominationId,
        electionId,
        role: 'SECRETARY',
        status: 'PENDING',
        nomineeMembership: {
          id: memberBMembershipId,
          userId: memberBUserId,
          user: { fullName: 'Bethlehem Tilahun' },
        },
      });

      (prisma.electionNomination.update as any).mockResolvedValue({
        id: nominationId,
        role: 'SECRETARY',
        status: 'DECLINED',
        declinedAt: new Date(),
        nomineeMembership: {
          id: memberBMembershipId,
          memberNumber: 'MBR-002',
          user: { id: memberBUserId, fullName: 'Bethlehem Tilahun' },
        },
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations/${nominationId}/respond`)
        .set('Authorization', `Bearer ${memberBToken}`)
        .send({ action: 'DECLINE' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('DECLINED');
      expect(res.body.message).toContain('Nomination declined');
    });

    it('forbids other members from responding to someone else nomination', async () => {
      const nominationId = 'nomination-pending-003';

      (prisma.electionNomination.findFirst as any).mockResolvedValue({
        id: nominationId,
        electionId,
        role: 'TREASURER',
        status: 'PENDING',
        nomineeMembership: {
          id: memberBMembershipId,
          userId: memberBUserId, // Nominee is B
          user: { fullName: 'Bethlehem Tilahun' },
        },
      });

      // Member A tries to respond
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations/${nominationId}/respond`)
        .set('Authorization', `Bearer ${memberAToken}`)
        .send({ action: 'ACCEPT' });

      expect(res.status).toBe(403);
      expect(res.body.error.message).toContain('Only the nominated member has authority');
    });
  });

  describe('PATCH /api/v1/idirs/:idirId/elections/:electionId/nominations/:nominationId/statement', () => {
    it('allows candidate to update their short statement', async () => {
      const nominationId = 'nomination-accepted-001';

      (prisma.electionNomination.findFirst as any).mockResolvedValue({
        id: nominationId,
        electionId,
        status: 'ACCEPTED',
        nomineeMembership: {
          id: memberAMembershipId,
          userId: memberAUserId,
        },
      });

      (prisma.electionNomination.update as any).mockResolvedValue({
        id: nominationId,
        statement: 'Updated platform: youth engagement and emergency fund expansion.',
      });

      const res = await request(app)
        .patch(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations/${nominationId}/statement`)
        .set('Authorization', `Bearer ${memberAToken}`)
        .send({
          statement: 'Updated platform: youth engagement and emergency fund expansion.',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toContain('Candidate statement updated successfully');
    });
  });

  describe('POST /api/v1/idirs/:idirId/elections/:electionId/nominations/:nominationId/withdraw', () => {
    it('allows candidate to withdraw their candidacy', async () => {
      const nominationId = 'nomination-accepted-002';

      (prisma.electionNomination.findFirst as any).mockResolvedValue({
        id: nominationId,
        electionId,
        role: 'CHAIRPERSON',
        status: 'ACCEPTED',
        nomineeMembership: {
          id: memberAMembershipId,
          userId: memberAUserId,
        },
      });

      (prisma.electionNomination.update as any).mockResolvedValue({
        id: nominationId,
        status: 'WITHDRAWN',
      });

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations/${nominationId}/withdraw`)
        .set('Authorization', `Bearer ${memberAToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('WITHDRAWN');
      expect(res.body.message).toContain('withdrawn successfully');
    });
  });

  describe('GET /api/v1/idirs/:idirId/elections/:electionId/nominations (Ballot & Nominations)', () => {
    it('by default returns ONLY ACCEPTED nominations for the ballot, excluding unaccepted ones', async () => {
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: memberAMembershipId,
        idirId,
        userId: memberAUserId,
        status: 'ACTIVE',
      });

      // Mock DB query returns only accepted candidates
      (prisma.electionNomination.findMany as any).mockResolvedValue([
        {
          id: 'nom-accepted-1',
          role: 'CHAIRPERSON',
          status: 'ACCEPTED',
          statement: 'Vision for unity',
          nomineeMembership: {
            id: memberAMembershipId,
            memberNumber: 'MBR-001',
            user: { id: memberAUserId, fullName: 'Abebe Bikila' },
          },
        },
      ]);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations`)
        .set('Authorization', `Bearer ${memberAToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0].status).toBe('ACCEPTED');

      // Verify that prisma was queried with status: 'ACCEPTED'
      expect(prisma.electionNomination.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            electionId,
            status: 'ACCEPTED',
          }),
        })
      );
    });

    it('allows querying ALL nominations (e.g. for election committee or admin view)', async () => {
      (prisma.membership.findUnique as any).mockResolvedValue({
        id: memberAMembershipId,
        idirId,
        userId: memberAUserId,
        status: 'ACTIVE',
      });

      (prisma.electionNomination.findMany as any).mockResolvedValue([
        { id: 'nom-1', status: 'ACCEPTED' },
        { id: 'nom-2', status: 'PENDING' },
        { id: 'nom-3', status: 'DECLINED' },
      ]);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations?status=ALL`)
        .set('Authorization', `Bearer ${memberAToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(3);
    });
  });

  describe('GET /api/v1/idirs/:idirId/elections/:electionId/nominations/:nominationId (Candidate Page)', () => {
    it('returns candidate profile and election details for candidate page', async () => {
      const nominationId = 'nomination-page-001';

      (prisma.membership.findUnique as any).mockResolvedValue({
        id: memberAMembershipId,
        idirId,
        userId: memberAUserId,
        status: 'ACTIVE',
      });

      (prisma.electionNomination.findFirst as any).mockResolvedValue({
        id: nominationId,
        role: 'CHAIRPERSON',
        status: 'ACCEPTED',
        statement: 'Dedicated to community transparency and digital services.',
        election: {
          id: electionId,
          title: 'Idir Leadership Election 2026',
          termLengthMonths: 24,
        },
        nomineeMembership: {
          id: memberAMembershipId,
          memberNumber: 'MBR-001',
          joinedAt: new Date('2023-01-01T00:00:00Z'),
          user: {
            id: memberAUserId,
            fullName: 'Abebe Bikila',
            phoneNumber: '+251911111111',
            faydaId: 'FAYDA-9876543210',
          },
        },
        nominatedByMembership: {
          id: memberAMembershipId,
          memberNumber: 'MBR-001',
          user: {
            id: memberAUserId,
            fullName: 'Abebe Bikila',
          },
        },
      });

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/elections/${electionId}/nominations/${nominationId}`)
        .set('Authorization', `Bearer ${memberAToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.id).toBe(nominationId);
      expect(res.body.data.nomineeMembership.user.fullName).toBe('Abebe Bikila');
      expect(res.body.data.statement).toContain('Dedicated to community transparency');
    });
  });
});
