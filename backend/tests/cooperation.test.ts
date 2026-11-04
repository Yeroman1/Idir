import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/config/database.js';
import { generateAccessToken } from '../src/shared/utils/jwt.js';

vi.mock('../src/config/database.js', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    membership: { findUnique: vi.fn(), findMany: vi.fn(), findFirst: vi.fn() },
    idir: { findUnique: vi.fn() },
    cooperationAgreement: {
      findMany: vi.fn(),
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
    cooperationParticipant: {
      findUnique: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      updateMany: vi.fn(),
    },
    jointInitiative: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
    initiativeUpdate: { create: vi.fn() },
    initiativeTask: { create: vi.fn() },
    crossIdirAnnouncement: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
    crossIdirEmergency: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
    emergencyResponse: { create: vi.fn() },
    jointFinancialCommitment: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
    expense: { create: vi.fn() },
    notification: { createMany: vi.fn() },
    auditLog: { create: vi.fn() },
    $transaction: vi.fn((callback) => callback(prisma)),
  },
}));

describe('Cross-Idir Cooperation Module (Security, Privacy & Approvals)', () => {
  const chairpersonAId = 'user-chairperson-a';
  const memberAId = 'user-member-a';
  const chairpersonBId = 'user-chairperson-b';
  const outsiderId = 'user-outsider-c';

  const idirA = '00000000-0000-0000-0000-000000000001';
  const idirB = '00000000-0000-0000-0000-000000000002';
  const idirC = '00000000-0000-0000-0000-000000000003';
  const agreementId = '11111111-1111-1111-1111-111111111111';

  let tokenChairpersonA: string;
  let tokenMemberA: string;
  let tokenChairpersonB: string;
  let tokenOutsiderC: string;

  beforeEach(() => {
    vi.clearAllMocks();

    tokenChairpersonA = generateAccessToken({ userId: chairpersonAId, phoneNumber: '+251911000001', isPlatformAdmin: false });
    tokenMemberA = generateAccessToken({ userId: memberAId, phoneNumber: '+251911000002', isPlatformAdmin: false });
    tokenChairpersonB = generateAccessToken({ userId: chairpersonBId, phoneNumber: '+251911000003', isPlatformAdmin: false });
    tokenOutsiderC = generateAccessToken({ userId: outsiderId, phoneNumber: '+251911000004', isPlatformAdmin: false });

    // Mock Users
    vi.mocked(prisma.user.findUnique).mockImplementation((args: any) => {
      const id = args.where?.id;
      return Promise.resolve({
        id,
        phoneNumber: '+251911000000',
        fullName: `User ${id}`,
        status: 'ACTIVE',
        isPlatformAdmin: false,
        preferredLanguage: 'am',
      } as any);
    });

    // Mock Active Idirs for assertIdirActive
    vi.mocked(prisma.idir.findUnique).mockImplementation((args: any) => {
      const id = args.where?.id;
      return Promise.resolve({
        id,
        name: id === idirA ? 'Bole Medhanealem Idir' : id === idirB ? 'Yeka Michael Idir' : 'Kirkos Idir',
        status: 'ACTIVE',
      } as any);
    });

    // Mock Memberships for authorize
    vi.mocked(prisma.membership.findUnique).mockImplementation((args: any) => {
      const { idirId, userId } = args.where?.idirId_userId ?? {};
      if (idirId === idirA && userId === chairpersonAId) {
        return Promise.resolve({ id: 'mem-a-1', idirId: idirA, role: 'CHAIRPERSON', status: 'ACTIVE', memberNumber: 'M-01' } as any);
      }
      if (idirId === idirA && userId === memberAId) {
        return Promise.resolve({ id: 'mem-a-2', idirId: idirA, role: 'MEMBER', status: 'ACTIVE', memberNumber: 'M-02' } as any);
      }
      if (idirId === idirB && userId === chairpersonBId) {
        return Promise.resolve({ id: 'mem-b-1', idirId: idirB, role: 'CHAIRPERSON', status: 'ACTIVE', memberNumber: 'M-03' } as any);
      }
      if (idirId === idirC && userId === outsiderId) {
        return Promise.resolve({ id: 'mem-c-1', idirId: idirC, role: 'CHAIRPERSON', status: 'ACTIVE', memberNumber: 'M-04' } as any);
      }
      return Promise.resolve(null);
    });
  });

  describe('1. Cooperation Requests & Approval Workflows', () => {
    it('allows an authorized Chairperson to propose cross-Idir cooperation', async () => {
      vi.mocked(prisma.cooperationAgreement.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.cooperationAgreement.create).mockResolvedValue({ id: agreementId } as any);
      vi.mocked(prisma.cooperationParticipant.create).mockResolvedValue({} as any);
      vi.mocked(prisma.membership.findMany).mockResolvedValue([{ userId: chairpersonBId }] as any);

      vi.mocked(prisma.cooperationAgreement.findUnique).mockResolvedValue({
        id: agreementId,
        idirAId: idirA,
        idirBId: idirB,
        idirA: { id: idirA, name: 'Bole Medhanealem Idir' },
        idirB: { id: idirB, name: 'Yeka Michael Idir' },
        purpose: 'Joint neighborhood emergency response',
        description: 'Collaborate on emergency assistance for fire or major losses',
        status: 'PENDING',
        proposedDuration: 180,
        createdAt: new Date(),
        participants: [
          { id: 'p1', agreementId, idirId: idirA, status: 'ACTIVE', idir: { id: idirA, name: 'Bole Medhanealem Idir' }, authorizedBy: { id: chairpersonAId, fullName: 'Chairperson A' } },
          { id: 'p2', agreementId, idirId: idirB, status: 'PENDING', idir: { id: idirB, name: 'Yeka Michael Idir' }, authorizedBy: null },
        ],
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirA}/cooperation`)
        .set('Authorization', `Bearer ${tokenChairpersonA}`)
        .send({
          targetIdirId: idirB,
          purpose: 'Joint neighborhood emergency response',
          description: 'Collaborate on emergency assistance for fire or major losses',
          proposedDuration: 180,
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('PENDING');
      expect(res.body.data.idirAName).toBe('Bole Medhanealem Idir');
      expect(res.body.data.idirBName).toBe('Yeka Michael Idir');
      expect(prisma.auditLog.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ action: 'PROPOSE_COOPERATION', entityId: agreementId }),
        })
      );
    });

    it('rejects cooperation proposal by an unauthorized regular member (403 Forbidden)', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirA}/cooperation`)
        .set('Authorization', `Bearer ${tokenMemberA}`)
        .send({
          targetIdirId: idirB,
          purpose: 'Unauthorized Proposal',
          description: 'Attempting to propose without leadership rights',
        });

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('Insufficient permissions');
    });

    it('prevents duplicate active or pending cooperation agreements between the same Idirs', async () => {
      vi.mocked(prisma.cooperationAgreement.findFirst).mockResolvedValue({
        id: 'existing-agreement-id',
        status: 'ACTIVE',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirA}/cooperation`)
        .set('Authorization', `Bearer ${tokenChairpersonA}`)
        .send({
          targetIdirId: idirB,
          purpose: 'Duplicate Proposal',
          description: 'This agreement already exists',
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('already exists');
    });

    it('prevents an Idir from proposing cooperation with itself', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirA}/cooperation`)
        .set('Authorization', `Bearer ${tokenChairpersonA}`)
        .send({
          targetIdirId: idirA,
          purpose: 'Self cooperation',
          description: 'Cannot cooperate with itself',
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('cannot propose cooperation with itself');
    });

    it('allows the receiving Idir to explicitly accept the cooperation agreement', async () => {
      const pendingAgreement = {
        id: agreementId,
        idirAId: idirA,
        idirBId: idirB,
        idirA: { id: idirA, name: 'Bole Medhanealem Idir' },
        idirB: { id: idirB, name: 'Yeka Michael Idir' },
        status: 'PENDING',
        purpose: 'Joint neighborhood emergency response',
        description: 'Collaborate on emergency assistance',
        participants: [
          { id: 'p1', agreementId, idirId: idirA, status: 'ACTIVE' },
          { id: 'p2', agreementId, idirId: idirB, status: 'PENDING' },
        ],
      };

      vi.mocked(prisma.cooperationAgreement.findUnique).mockResolvedValue(pendingAgreement as any);
      vi.mocked(prisma.cooperationParticipant.update).mockResolvedValue({} as any);
      vi.mocked(prisma.cooperationAgreement.update).mockResolvedValue({} as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirB}/cooperation/${agreementId}/respond`)
        .set('Authorization', `Bearer ${tokenChairpersonB}`)
        .send({ action: 'accept' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(prisma.cooperationParticipant.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { agreementId_idirId: { agreementId, idirId: idirB } },
          data: expect.objectContaining({ status: 'ACTIVE', authorizedById: chairpersonBId }),
        })
      );
      expect(prisma.cooperationAgreement.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: agreementId },
          data: expect.objectContaining({ status: 'ACTIVE' }),
        })
      );
    });

    it('prevents the proposing Idir from accepting on behalf of the receiving Idir (403 Forbidden)', async () => {
      const pendingAgreement = {
        id: agreementId,
        idirAId: idirA,
        idirBId: idirB,
        idirA: { id: idirA, name: 'Bole Medhanealem Idir' },
        idirB: { id: idirB, name: 'Yeka Michael Idir' },
        status: 'PENDING',
        participants: [],
      };

      vi.mocked(prisma.cooperationAgreement.findUnique).mockResolvedValue(pendingAgreement as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirA}/cooperation/${agreementId}/respond`)
        .set('Authorization', `Bearer ${tokenChairpersonA}`)
        .send({ action: 'accept' });

      expect(res.status).toBe(403);
      expect(res.body.error.message).toContain('Only the receiving Idir can accept or reject');
    });

    it('allows an authorized representative to end an active cooperation agreement', async () => {
      const activeAgreement = {
        id: agreementId,
        idirAId: idirA,
        idirBId: idirB,
        idirA: { id: idirA, name: 'Bole Medhanealem Idir' },
        idirB: { id: idirB, name: 'Yeka Michael Idir' },
        status: 'ACTIVE',
        participants: [{ idirId: idirA }, { idirId: idirB }],
      };

      vi.mocked(prisma.cooperationAgreement.findUnique).mockResolvedValue(activeAgreement as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirA}/cooperation/${agreementId}/end`)
        .set('Authorization', `Bearer ${tokenChairpersonA}`)
        .send({ reason: 'Objectives achieved for this quarter' });

      expect(res.status).toBe(200);
      expect(prisma.cooperationAgreement.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: agreementId },
          data: expect.objectContaining({ status: 'COMPLETED', endReason: 'Objectives achieved for this quarter' }),
        })
      );
      expect(prisma.auditLog.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ action: 'END_COOPERATION' }),
        })
      );
    });
  });

  describe('2. Cross-Idir Data Isolation & Privacy', () => {
    it('strictly forbids a non-participating third Idir from viewing or accessing cooperation data', async () => {
      const agreementAB = {
        id: agreementId,
        idirAId: idirA,
        idirBId: idirB,
        idirA: { id: idirA, name: 'Bole Medhanealem Idir' },
        idirB: { id: idirB, name: 'Yeka Michael Idir' },
        status: 'ACTIVE',
        participants: [{ idirId: idirA }, { idirId: idirB }],
      };

      vi.mocked(prisma.cooperationAgreement.findUnique).mockResolvedValue(agreementAB as any);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirC}/cooperation/${agreementId}`)
        .set('Authorization', `Bearer ${tokenOutsiderC}`);

      expect(res.status).toBe(403);
      expect(res.body.error.message).toContain('You do not have access to this cross-Idir cooperation agreement');
    });

    it('blocks creation of initiatives when agreement is ended or not active', async () => {
      const endedAgreement = {
        id: agreementId,
        idirAId: idirA,
        idirBId: idirB,
        status: 'COMPLETED',
        participants: [{ idirId: idirA }, { idirId: idirB }],
      };

      vi.mocked(prisma.cooperationAgreement.findUnique).mockResolvedValue(endedAgreement as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirA}/cooperation/${agreementId}/initiatives`)
        .set('Authorization', `Bearer ${tokenChairpersonA}`)
        .send({
          title: 'Post-end Initiative',
          description: 'Should be rejected',
          objectives: 'Test security constraint',
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('Active status required');
    });
  });

  describe('3. Joint Community Initiatives & Cross Announcements', () => {
    it('creates an initiative and registers tasks for participating Idirs', async () => {
      const activeAgreement = {
        id: agreementId,
        idirAId: idirA,
        idirBId: idirB,
        idirA: { id: idirA, name: 'Bole Medhanealem Idir' },
        idirB: { id: idirB, name: 'Yeka Michael Idir' },
        status: 'ACTIVE',
        participants: [{ idirId: idirA }, { idirId: idirB }],
      };

      vi.mocked(prisma.cooperationAgreement.findUnique).mockResolvedValue(activeAgreement as any);
      vi.mocked(prisma.jointInitiative.create).mockResolvedValue({
        id: 'init-1',
        title: 'Community Tree Planting & Road Repair',
        description: 'Joint weekend community service',
        objectives: 'Plant 500 seedlings',
        category: 'COMMUNITY_SUPPORT',
        status: 'ACTIVE',
        ownerIdirId: idirA,
      } as any);

      vi.mocked(prisma.jointInitiative.findFirst).mockResolvedValue({
        id: 'init-1',
        agreementId,
        title: 'Community Tree Planting & Road Repair',
        description: 'Joint weekend community service',
        objectives: 'Plant 500 seedlings',
        category: 'COMMUNITY_SUPPORT',
        status: 'ACTIVE',
        ownerIdirId: idirA,
        ownerIdir: { id: idirA, name: 'Bole Medhanealem Idir' },
        updates: [],
        tasks: [],
        createdAt: new Date(),
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirA}/cooperation/${agreementId}/initiatives`)
        .set('Authorization', `Bearer ${tokenChairpersonA}`)
        .send({
          title: 'Community Tree Planting & Road Repair',
          description: 'Joint weekend community service',
          objectives: 'Plant 500 seedlings',
          category: 'COMMUNITY_SUPPORT',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.title).toBe('Community Tree Planting & Road Repair');
      expect(res.body.data.ownerIdirName).toBe('Bole Medhanealem Idir');
    });

    it('publishes a cross-Idir announcement and dispatches notification to participating Idirs', async () => {
      const activeAgreement = {
        id: agreementId,
        idirAId: idirA,
        idirBId: idirB,
        status: 'ACTIVE',
        participants: [{ idirId: idirA }, { idirId: idirB }],
      };

      vi.mocked(prisma.cooperationAgreement.findUnique).mockResolvedValue(activeAgreement as any);
      vi.mocked(prisma.crossIdirAnnouncement.create).mockResolvedValue({
        id: 'ann-1',
        agreementId,
        publisherIdirId: idirA,
        publisherIdir: { id: idirA, name: 'Bole Medhanealem Idir' },
        title: 'Emergency Flood Relief Gathering',
        body: 'Urgent coordination meeting tomorrow at 10 AM',
        category: 'EMERGENCY',
        isWithdrawn: false,
        createdBy: { id: chairpersonAId, fullName: 'Chairperson A' },
        createdAt: new Date(),
      } as any);

      vi.mocked(prisma.membership.findMany).mockResolvedValue([
        { userId: 'user-a-1', idirId: idirA },
        { userId: 'user-b-1', idirId: idirB },
      ] as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirA}/cooperation/${agreementId}/announcements`)
        .set('Authorization', `Bearer ${tokenChairpersonA}`)
        .send({
          title: 'Emergency Flood Relief Gathering',
          body: 'Urgent coordination meeting tomorrow at 10 AM',
          category: 'EMERGENCY',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.title).toBe('Emergency Flood Relief Gathering');
      expect(prisma.notification.createMany).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.arrayContaining([
            expect.objectContaining({ title: '[Joint Announcement] Emergency Flood Relief Gathering' }),
          ]),
        })
      );
    });
  });

  describe('4. Emergency Coordination Workflow', () => {
    it('creates an emergency request and records assistance responses', async () => {
      const activeAgreement = {
        id: agreementId,
        idirAId: idirA,
        idirBId: idirB,
        status: 'ACTIVE',
        participants: [{ idirId: idirA }, { idirId: idirB }],
      };

      vi.mocked(prisma.cooperationAgreement.findUnique).mockResolvedValue(activeAgreement as any);
      vi.mocked(prisma.crossIdirEmergency.create).mockResolvedValue({
        id: 'emg-1',
        agreementId,
        requestingIdirId: idirA,
        requestingIdir: { id: idirA, name: 'Bole Medhanealem Idir' },
        title: 'Fire in Kebele 04 Market Area',
        description: 'Several shops and residential compounds affected',
        emergencyType: 'FIRE',
        urgency: 'CRITICAL',
        status: 'OPEN',
        createdAt: new Date(),
        responses: [],
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirA}/cooperation/${agreementId}/emergencies`)
        .set('Authorization', `Bearer ${tokenChairpersonA}`)
        .send({
          title: 'Fire in Kebele 04 Market Area',
          description: 'Several shops and residential compounds affected',
          emergencyType: 'FIRE',
          urgency: 'CRITICAL',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.urgency).toBe('CRITICAL');
      expect(res.body.data.status).toBe('OPEN');

      // Partner responds to emergency
      vi.mocked(prisma.crossIdirEmergency.findFirst).mockResolvedValue({
        id: 'emg-1',
        agreementId,
        status: 'OPEN',
      } as any);

      const res2 = await request(app)
        .post(`/api/v1/idirs/${idirB}/cooperation/${agreementId}/emergencies/emg-1/respond`)
        .set('Authorization', `Bearer ${tokenChairpersonB}`)
        .send({
          message: 'Deploying volunteer relief team and emergency shelter supplies',
          commitmentNote: '50 emergency tents and 100 blankets',
        });

      expect(res2.status).toBe(201);
      expect(prisma.crossIdirEmergency.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'emg-1' },
          data: { status: 'ACKNOWLEDGED' },
        })
      );
    });
  });

  describe('5. Optional Joint Financial Support & Reconciliation', () => {
    it('creates financial commitment, enforces explicit authorization, and confirms with Expense link', async () => {
      const activeAgreement = {
        id: agreementId,
        idirAId: idirA,
        idirBId: idirB,
        status: 'ACTIVE',
        participants: [{ idirId: idirA }, { idirId: idirB }],
      };

      vi.mocked(prisma.cooperationAgreement.findUnique).mockResolvedValue(activeAgreement as any);

      // 1. Create Commitment
      vi.mocked(prisma.jointFinancialCommitment.create).mockResolvedValue({
        id: 'comm-1',
        agreementId,
        contributingIdirId: idirA,
        contributingIdir: { id: idirA, name: 'Bole Medhanealem Idir' },
        amountCommitted: 15000,
        amountConfirmed: 0,
        currency: 'ETB',
        purpose: 'Relief fund for affected members',
        status: 'PENDING',
        createdAt: new Date(),
      } as any);

      const createRes = await request(app)
        .post(`/api/v1/idirs/${idirA}/cooperation/${agreementId}/commitments`)
        .set('Authorization', `Bearer ${tokenChairpersonA}`)
        .send({
          amountCommitted: 15000,
          purpose: 'Relief fund for affected members',
        });

      expect(createRes.status).toBe(201);
      expect(createRes.body.data.status).toBe('PENDING');

      // 2. Authorize Commitment
      vi.mocked(prisma.jointFinancialCommitment.findFirst).mockResolvedValue({
        id: 'comm-1',
        agreementId,
        contributingIdirId: idirA,
        status: 'PENDING',
      } as any);

      const authRes = await request(app)
        .post(`/api/v1/idirs/${idirA}/cooperation/${agreementId}/commitments/comm-1/authorize`)
        .set('Authorization', `Bearer ${tokenChairpersonA}`);

      expect(authRes.status).toBe(200);
      expect(prisma.jointFinancialCommitment.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'comm-1' },
          data: expect.objectContaining({ status: 'AUTHORIZED', authorizedById: chairpersonAId }),
        })
      );

      // 3. Confirm Commitment & link to existing financial records (Expense)
      vi.mocked(prisma.jointFinancialCommitment.findFirst).mockResolvedValue({
        id: 'comm-1',
        agreementId,
        contributingIdirId: idirA,
        currency: 'ETB',
        purpose: 'Relief fund for affected members',
        status: 'AUTHORIZED',
      } as any);

      vi.mocked(prisma.expense.create).mockResolvedValue({ id: 'exp-reconciled-1' } as any);

      const confirmRes = await request(app)
        .post(`/api/v1/idirs/${idirA}/cooperation/${agreementId}/commitments/comm-1/confirm`)
        .set('Authorization', `Bearer ${tokenChairpersonA}`)
        .send({
          amountConfirmed: 15000,
          reconciliationNote: 'Reconciled via Commercial Bank of Ethiopia transfer receipt #TR-88291',
        });

      expect(confirmRes.status).toBe(200);
      expect(prisma.expense.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            idirId: idirA,
            description: expect.stringContaining('Relief fund for affected members'),
          }),
        })
      );
      expect(prisma.jointFinancialCommitment.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'comm-1' },
          data: expect.objectContaining({
            status: 'CONFIRMED',
            amountConfirmed: 15000,
            expenseId: 'exp-reconciled-1',
          }),
        })
      );
    });
  });
});
