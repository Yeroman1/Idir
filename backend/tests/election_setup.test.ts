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
      create: vi.fn(),
      findFirst: vi.fn(),
      findMany: vi.fn(),
      count: vi.fn(),
      update: vi.fn(),
    },
    electionCommitteeMember: {
      create: vi.fn(),
      createMany: vi.fn(),
      deleteMany: vi.fn(),
    },
    auditLog: { create: vi.fn() },
    $transaction: vi.fn((callback) => callback(prisma)),
  },
}));

describe('Task 1: Leadership Election Setup & Governance Authorization', () => {
  const idirId = '11111111-1111-1111-1111-111111111111';
  const chairpersonUserId = 'chairperson-user-uuid';
  const creatorUserId = 'creator-user-uuid';
  const secretaryUserId = 'secretary-user-uuid';
  const committeeOfficerUserId = 'committee-officer-user-uuid';
  const regularMemberUserId = 'regular-member-user-uuid';
  const auditorUserId = 'auditor-user-uuid';

  const neutralMember1Id = 'member-neutral-uuid-001';
  const neutralMember2Id = 'member-neutral-uuid-002';

  let chairpersonToken: string;
  let creatorToken: string;
  let secretaryToken: string;
  let committeeOfficerToken: string;
  let memberToken: string;
  let auditorToken: string;

  const validPayload = {
    title: 'Idir Executive Committee General Election 2026',
    description: 'Biannual leadership election for Chairperson, Treasurer, and Secretary',
    roles: ['CHAIRPERSON', 'TREASURER', 'SECRETARY'],
    startDate: '2026-11-01T08:00:00.000Z',
    endDate: '2026-11-03T18:00:00.000Z',
    nominationStartDate: '2026-10-25T08:00:00.000Z',
    nominationEndDate: '2026-10-31T18:00:00.000Z',
    termLengthMonths: 24,
    votingMethod: 'SIMPLE_MAJORITY',
    ballotType: 'SECRET',
    quorumPercentage: 50.0,
    minMembershipTenureDays: 90,
    requiresGoodStanding: true,
    disputeWindowHours: 48,
    handoverDate: '2026-11-10T10:00:00.000Z',
    committeeMemberIds: [neutralMember1Id, neutralMember2Id],
  };

  beforeEach(() => {
    vi.clearAllMocks();

    chairpersonToken = generateAccessToken({
      userId: chairpersonUserId,
      phoneNumber: '+251911000001',
      isPlatformAdmin: false,
    });

    creatorToken = generateAccessToken({
      userId: creatorUserId,
      phoneNumber: '+251911000002',
      isPlatformAdmin: false,
    });

    secretaryToken = generateAccessToken({
      userId: secretaryUserId,
      phoneNumber: '+251911000003',
      isPlatformAdmin: false,
    });

    committeeOfficerToken = generateAccessToken({
      userId: committeeOfficerUserId,
      phoneNumber: '+251911000004',
      isPlatformAdmin: false,
    });

    memberToken = generateAccessToken({
      userId: regularMemberUserId,
      phoneNumber: '+251911000005',
      isPlatformAdmin: false,
    });

    auditorToken = generateAccessToken({
      userId: auditorUserId,
      phoneNumber: '+251911000006',
      isPlatformAdmin: false,
    });

    // Default mock user lookup for authenticate middleware
    vi.mocked(prisma.user.findUnique).mockImplementation((async ({ where }: any) => {
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
    }) as any);

    // Default mock Idir is ACTIVE
    vi.mocked(prisma.idir.findUnique).mockResolvedValue({
      id: idirId,
      name: 'Bole Medhanealem Idir',
      status: 'ACTIVE',
    } as any);

    // Default neutral committee members exist and are active members of this Idir
    vi.mocked(prisma.membership.findMany).mockImplementation((async ({ where }: any) => {
      if (where.id && where.id.in) {
        const ids: string[] = where.id.in;
        return ids.map((id, index) => ({
          id,
          idirId,
          userId: `user-${id}`,
          memberNumber: `MEM-${100 + index}`,
          role: 'MEMBER',
          status: 'ACTIVE',
          user: {
            id: `user-${id}`,
            fullName: `Neutral Member ${index + 1}`,
            phoneNumber: `+25191122233${index}`,
          },
        })) as any;
      }
      return [];
    }) as any);
  });

  describe('1. Role Authorization Gates: Only Allowed Officers Can Create an Election', () => {
    it('allows CHAIRPERSON to create an election setup and logs audit record', async () => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: 'membership-chairperson-id',
        idirId,
        userId: chairpersonUserId,
        role: 'CHAIRPERSON',
        memberNumber: 'MEM-001',
        status: 'ACTIVE',
      } as any);

      vi.mocked(prisma.election.create).mockResolvedValue({
        id: 'election-uuid-001',
        idirId,
        title: validPayload.title,
        roles: validPayload.roles,
        startDate: new Date(validPayload.startDate),
        endDate: new Date(validPayload.endDate),
        termLengthMonths: validPayload.termLengthMonths,
        votingMethod: validPayload.votingMethod,
        ballotType: validPayload.ballotType,
        quorumPercentage: validPayload.quorumPercentage,
        status: 'DRAFT',
        committeeMembers: [
          { membershipId: neutralMember1Id, role: 'COMMITTEE_MEMBER' },
          { membershipId: neutralMember2Id, role: 'COMMITTEE_MEMBER' },
        ],
        createdBy: { id: chairpersonUserId, fullName: 'Chairperson Test' },
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send(validPayload);

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.id).toBe('election-uuid-001');
      expect(res.body.data.title).toBe(validPayload.title);

      // Verify audit trail logged
      expect(prisma.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          action: 'CREATE_ELECTION',
          entityType: 'Election',
          actorId: chairpersonUserId,
          idirId,
        }),
      });
    });

    it('allows CREATOR, SECRETARY, and COMMITTEE officers to create an election', async () => {
      for (const [token, role, userId] of [
        [creatorToken, 'CREATOR', creatorUserId],
        [secretaryToken, 'SECRETARY', secretaryUserId],
        [committeeOfficerToken, 'COMMITTEE', committeeOfficerUserId],
      ] as const) {
        vi.mocked(prisma.membership.findUnique).mockResolvedValue({
          id: `membership-${role.toLowerCase()}-id`,
          idirId,
          userId,
          role,
          memberNumber: 'MEM-002',
          status: 'ACTIVE',
        } as any);

        vi.mocked(prisma.election.create).mockResolvedValue({
          id: `election-${role.toLowerCase()}`,
          idirId,
          title: validPayload.title,
          roles: validPayload.roles,
          startDate: new Date(validPayload.startDate),
          endDate: new Date(validPayload.endDate),
          termLengthMonths: validPayload.termLengthMonths,
          votingMethod: validPayload.votingMethod,
          ballotType: validPayload.ballotType,
          quorumPercentage: validPayload.quorumPercentage,
          status: 'DRAFT',
          committeeMembers: [],
          createdBy: { id: userId, fullName: `${role} User` },
        } as any);

        const res = await request(app)
          .post(`/api/v1/idirs/${idirId}/elections`)
          .set('Authorization', `Bearer ${token}`)
          .send(validPayload);

        expect(res.status).toBe(201);
        expect(res.body.success).toBe(true);
      }
    });

    it('rejects regular MEMBER with 403 Forbidden', async () => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: 'membership-member-id',
        idirId,
        userId: regularMemberUserId,
        role: 'MEMBER',
        memberNumber: 'MEM-099',
        status: 'ACTIVE',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send(validPayload);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('FORBIDDEN');
      expect(res.body.error.message).toContain('Insufficient permissions');
    });

    it('rejects AUDITOR with 403 Forbidden', async () => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: 'membership-auditor-id',
        idirId,
        userId: auditorUserId,
        role: 'AUDITOR',
        memberNumber: 'MEM-050',
        status: 'ACTIVE',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${auditorToken}`)
        .send(validPayload);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('FORBIDDEN');
    });

    it('rejects unauthenticated requests with 401 Unauthorized', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .send(validPayload);

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('rejects non-members with 403 Forbidden', async () => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue(null);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send(validPayload);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('not an active member');
    });

    it('blocks election creation when Idir is in DRAFT or SUSPENDED status', async () => {
      vi.mocked(prisma.idir.findUnique).mockResolvedValue({
        id: idirId,
        name: 'Draft Idir',
        status: 'DRAFT',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send(validPayload);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('Available once this Idir is active');
    });
  });

  describe('2. Validation & Invalid Settings Rejection', () => {
    beforeEach(() => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: 'membership-chairperson-id',
        idirId,
        userId: chairpersonUserId,
        role: 'CHAIRPERSON',
        memberNumber: 'MEM-001',
        status: 'ACTIVE',
      } as any);
    });

    it('rejects when title is missing or too short', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ ...validPayload, title: 'El' });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(res.body.error.details).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ field: 'title' }),
        ])
      );
    });

    it('rejects empty contested roles list', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ ...validPayload, roles: [] });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.details).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ field: 'roles' }),
        ])
      );
    });

    it('rejects non-electable or invalid roles (e.g. MEMBER or CREATOR)', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ ...validPayload, roles: ['MEMBER'] });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('rejects duplicate roles in the election setup', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ ...validPayload, roles: ['CHAIRPERSON', 'CHAIRPERSON'] });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.details).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            message: 'Duplicate roles cannot be specified in the same election',
          }),
        ])
      );
    });

    it('rejects when voting endDate is on or before startDate', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({
          ...validPayload,
          startDate: '2026-11-05T10:00:00.000Z',
          endDate: '2026-11-03T10:00:00.000Z',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.details).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            field: 'endDate',
            message: 'Election end date must be strictly after start date',
          }),
        ])
      );
    });

    it('rejects nomination end date that falls after voting start date', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({
          ...validPayload,
          startDate: '2026-11-01T08:00:00.000Z',
          nominationEndDate: '2026-11-02T10:00:00.000Z',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.details).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            field: 'nominationEndDate',
            message: 'Nomination period must conclude on or before voting start date',
          }),
        ])
      );
    });

    it('rejects invalid or non-positive termLengthMonths', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ ...validPayload, termLengthMonths: 0 });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.details).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ field: 'termLengthMonths' }),
        ])
      );
    });

    it('rejects invalid voting method', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ ...validPayload, votingMethod: 'RANKED_CHOICE' });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.details).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ field: 'votingMethod' }),
        ])
      );
    });

    it('rejects invalid ballot type', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ ...validPayload, ballotType: 'VOICE_VOTE' });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.details).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ field: 'ballotType' }),
        ])
      );
    });

    it('rejects quorumPercentage less than 1 or greater than 100', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ ...validPayload, quorumPercentage: 105 });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.details).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ field: 'quorumPercentage' }),
        ])
      );
    });

    it('rejects handover date that precedes election end date', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({
          ...validPayload,
          endDate: '2026-11-05T18:00:00.000Z',
          handoverDate: '2026-11-04T10:00:00.000Z',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.details).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            field: 'handoverDate',
            message: 'Leadership handover date cannot precede election end date',
          }),
        ])
      );
    });
  });

  describe('3. Neutral Election Committee Integrity & Assignment', () => {
    beforeEach(() => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: 'membership-chairperson-id',
        idirId,
        userId: chairpersonUserId,
        role: 'CHAIRPERSON',
        memberNumber: 'MEM-001',
        status: 'ACTIVE',
      } as any);
    });

    it('rejects empty committeeMemberIds list', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ ...validPayload, committeeMemberIds: [] });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.details).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            field: 'committeeMemberIds',
            message: 'At least one neutral election committee member must be assigned',
          }),
        ])
      );
    });

    it('rejects duplicate committee members in assignment', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({
          ...validPayload,
          committeeMemberIds: [neutralMember1Id, neutralMember1Id],
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.details).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            message: 'Duplicate committee members cannot be assigned',
          }),
        ])
      );
    });

    it('rejects if any committee member is not an active member of this Idir', async () => {
      // Return only 1 found member instead of 2
      vi.mocked(prisma.membership.findMany).mockResolvedValue([
        {
          id: neutralMember1Id,
          idirId,
          userId: 'user-1',
          role: 'MEMBER',
          status: 'ACTIVE',
        },
      ] as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send(validPayload);

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain(
        'All election committee members must be active members of this Idir'
      );
    });
  });

  describe('4. List, Read, Update, and Cancel Elections', () => {
    it('allows active members to list elections with pagination', async () => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: 'membership-member-id',
        idirId,
        userId: regularMemberUserId,
        role: 'MEMBER',
        memberNumber: 'MEM-099',
        status: 'ACTIVE',
      } as any);

      vi.mocked(prisma.election.findMany).mockResolvedValue([
        {
          id: 'election-uuid-001',
          title: '2026 General Election',
          status: 'VOTING',
          committeeMembers: [],
          _count: { nominations: 4, voteReceipts: 32 },
        },
      ] as any);
      vi.mocked(prisma.election.count).mockResolvedValue(1);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/elections?page=1&limit=10`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.pagination.total).toBe(1);
    });

    it('allows active members to fetch election details by ID', async () => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: 'membership-member-id',
        idirId,
        userId: regularMemberUserId,
        role: 'MEMBER',
        memberNumber: 'MEM-099',
        status: 'ACTIVE',
      } as any);

      vi.mocked(prisma.election.findFirst).mockResolvedValue({
        id: 'election-uuid-001',
        idirId,
        title: '2026 General Election',
        committeeMembers: [],
        nominations: [],
        results: [],
        createdBy: { id: chairpersonUserId, fullName: 'Chairperson' },
      } as any);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/elections/election-uuid-001`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.id).toBe('election-uuid-001');
    });

    it('allows authorized officers to update settings while in DRAFT status', async () => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: 'membership-chairperson-id',
        idirId,
        userId: chairpersonUserId,
        role: 'CHAIRPERSON',
        memberNumber: 'MEM-001',
        status: 'ACTIVE',
      } as any);

      vi.mocked(prisma.election.findFirst).mockResolvedValue({
        id: 'election-uuid-001',
        idirId,
        status: 'DRAFT',
      } as any);

      vi.mocked(prisma.election.update).mockResolvedValue({
        id: 'election-uuid-001',
        title: 'Updated Election Title',
        status: 'DRAFT',
      } as any);

      const res = await request(app)
        .patch(`/api/v1/idirs/${idirId}/elections/election-uuid-001`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ title: 'Updated Election Title' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.title).toBe('Updated Election Title');
    });

    it('rejects updating election settings once the election has advanced beyond DRAFT', async () => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: 'membership-chairperson-id',
        idirId,
        userId: chairpersonUserId,
        role: 'CHAIRPERSON',
        memberNumber: 'MEM-001',
        status: 'ACTIVE',
      } as any);

      vi.mocked(prisma.election.findFirst).mockResolvedValue({
        id: 'election-uuid-001',
        idirId,
        status: 'VOTING',
      } as any);

      const res = await request(app)
        .patch(`/api/v1/idirs/${idirId}/elections/election-uuid-001`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ title: 'Updated Election Title' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('advanced beyond DRAFT');
    });

    it('allows authorized officers to cancel an election', async () => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: 'membership-chairperson-id',
        idirId,
        userId: chairpersonUserId,
        role: 'CHAIRPERSON',
        memberNumber: 'MEM-001',
        status: 'ACTIVE',
      } as any);

      vi.mocked(prisma.election.findFirst).mockResolvedValue({
        id: 'election-uuid-001',
        idirId,
        status: 'DRAFT',
      } as any);

      vi.mocked(prisma.election.update).mockResolvedValue({
        id: 'election-uuid-001',
        status: 'CANCELLED',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/elections/election-uuid-001/cancel`)
        .set('Authorization', `Bearer ${chairpersonToken}`)
        .send({ reason: 'Quorum bylaws revision pending' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('CANCELLED');
    });
  });
});
