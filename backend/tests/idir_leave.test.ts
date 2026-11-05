import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/config/database.js';
import { generateAccessToken } from '../src/shared/utils/jwt.js';

vi.mock('../src/config/database.js', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    idir: { findUnique: vi.fn(), update: vi.fn() },
    membership: { findFirst: vi.fn(), update: vi.fn(), delete: vi.fn() },
    contribution: { count: vi.fn() },
    ikubParticipant: { count: vi.fn() },
    auditLog: { create: vi.fn() },
    $transaction: vi.fn((callback) => callback(prisma)),
  },
}));

describe('Idir Leave / Exit Feature Tests', () => {
  const creatorUserId = 'creator-user-uuid';
  const regularUserId = 'member-user-uuid';
  const testIdirId = 'idir-test-uuid-001';

  let creatorToken: string;
  let memberToken: string;

  beforeEach(() => {
    vi.clearAllMocks();

    creatorToken = generateAccessToken({
      userId: creatorUserId,
      phoneNumber: '+251911111111',
      isPlatformAdmin: false,
    });

    memberToken = generateAccessToken({
      userId: regularUserId,
      phoneNumber: '+251922222222',
      isPlatformAdmin: false,
    });

    vi.mocked(prisma.user.findUnique).mockImplementation((args: any) => {
      if (args.where.id === creatorUserId) {
        return Promise.resolve({
          id: creatorUserId,
          phoneNumber: '+251911111111',
          fullName: 'Idir Founder & Chairperson',
          status: 'ACTIVE',
          isPlatformAdmin: false,
        } as any);
      }
      if (args.where.id === regularUserId) {
        return Promise.resolve({
          id: regularUserId,
          phoneNumber: '+251922222222',
          fullName: 'Regular Member',
          status: 'ACTIVE',
          isPlatformAdmin: false,
        } as any);
      }
      return Promise.resolve(null);
    });
  });

  it('rejects unauthenticated user with 401', async () => {
    const res = await request(app).post(`/api/v1/idirs/${testIdirId}/leave`);
    expect(res.status).toBe(401);
  });

  it('rejects user who has no membership and did not create the idir (404)', async () => {
    vi.mocked(prisma.idir.findUnique).mockResolvedValue({
      id: testIdirId,
      name: 'St. George Idir',
      createdById: 'someone-else-uuid',
      memberships: [],
    } as any);

    vi.mocked(prisma.membership.findFirst).mockResolvedValue(null);

    const res = await request(app)
      .post(`/api/v1/idirs/${testIdirId}/leave`)
      .set('Authorization', `Bearer ${memberToken}`);

    expect(res.status).toBe(404);
    expect(res.body.error?.message || res.body.message).toContain('No active membership found');
  });

  it('allows a regular member to leave an Idir cleanly', async () => {
    vi.mocked(prisma.idir.findUnique).mockResolvedValue({
      id: testIdirId,
      name: 'St. George Idir',
      createdById: creatorUserId,
      memberships: [
        { id: 'm-creator', userId: creatorUserId, role: 'CHAIRPERSON', status: 'ACTIVE', joinedAt: new Date(2025, 0, 1) },
        { id: 'm-reg', userId: regularUserId, role: 'MEMBER', status: 'ACTIVE', joinedAt: new Date(2025, 1, 1) },
      ],
    } as any);

    vi.mocked(prisma.membership.findFirst).mockResolvedValue({
      id: 'm-reg',
      idirId: testIdirId,
      userId: regularUserId,
      role: 'MEMBER',
      status: 'ACTIVE',
    } as any);

    vi.mocked(prisma.contribution.count).mockResolvedValue(0);
    vi.mocked(prisma.ikubParticipant.count).mockResolvedValue(0);
    vi.mocked(prisma.membership.delete).mockResolvedValue({ id: 'm-reg' } as any);
    vi.mocked(prisma.auditLog.create).mockResolvedValue({ id: 'audit-01' } as any);

    const res = await request(app)
      .post(`/api/v1/idirs/${testIdirId}/leave`)
      .set('Authorization', `Bearer ${memberToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.wasCreator).toBe(false);
    expect(prisma.membership.delete).toHaveBeenCalledWith({ where: { id: 'm-reg' } });
    expect(prisma.auditLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          action: 'LEAVE_IDIR',
          actorId: regularUserId,
        }),
      })
    );
  });

  it('allows the creator / chairperson to leave when other active members exist, reassigning leadership', async () => {
    const successorUserId = 'successor-uuid';
    vi.mocked(prisma.idir.findUnique).mockResolvedValue({
      id: testIdirId,
      name: 'Pioneer Community Idir',
      createdById: creatorUserId,
      memberships: [
        { id: 'm-creator', userId: creatorUserId, role: 'CHAIRPERSON', status: 'ACTIVE', joinedAt: new Date(2025, 0, 1) },
        { id: 'm-succ', userId: successorUserId, role: 'TREASURER', status: 'ACTIVE', joinedAt: new Date(2025, 0, 15) },
      ],
    } as any);

    vi.mocked(prisma.membership.findFirst).mockResolvedValue({
      id: 'm-creator',
      idirId: testIdirId,
      userId: creatorUserId,
      role: 'CHAIRPERSON',
      status: 'ACTIVE',
    } as any);

    vi.mocked(prisma.contribution.count).mockResolvedValue(0);
    vi.mocked(prisma.ikubParticipant.count).mockResolvedValue(0);
    vi.mocked(prisma.membership.update).mockResolvedValue({ id: 'm-succ', role: 'CHAIRPERSON' } as any);
    vi.mocked(prisma.membership.delete).mockResolvedValue({ id: 'm-creator' } as any);
    vi.mocked(prisma.idir.update).mockResolvedValue({ id: testIdirId } as any);
    vi.mocked(prisma.auditLog.create).mockResolvedValue({ id: 'audit-02' } as any);

    const res = await request(app)
      .post(`/api/v1/idirs/${testIdirId}/leave`)
      .set('Authorization', `Bearer ${creatorToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.wasCreator).toBe(true);

    // Verify successor was promoted to CHAIRPERSON
    expect(prisma.membership.update).toHaveBeenCalledWith({
      where: { id: 'm-succ' },
      data: { role: 'CHAIRPERSON' },
    });

    // Verify creator's createdById was handed off to the new leader
    expect(prisma.idir.update).toHaveBeenCalledWith({
      where: { id: testIdirId },
      data: { createdById: successorUserId },
    });
  });

  it('allows the creator to leave even if they are the sole member, closing the idir', async () => {
    vi.mocked(prisma.idir.findUnique).mockResolvedValue({
      id: testIdirId,
      name: 'Solo Creator Idir',
      createdById: creatorUserId,
      memberships: [
        { id: 'm-creator', userId: creatorUserId, role: 'CHAIRPERSON', status: 'ACTIVE', joinedAt: new Date(2025, 0, 1) },
      ],
    } as any);

    vi.mocked(prisma.membership.findFirst).mockResolvedValue({
      id: 'm-creator',
      idirId: testIdirId,
      userId: creatorUserId,
      role: 'CHAIRPERSON',
      status: 'ACTIVE',
    } as any);

    vi.mocked(prisma.contribution.count).mockResolvedValue(0);
    vi.mocked(prisma.ikubParticipant.count).mockResolvedValue(0);
    vi.mocked(prisma.membership.delete).mockResolvedValue({ id: 'm-creator' } as any);
    vi.mocked(prisma.idir.update).mockResolvedValue({ id: testIdirId } as any);
    vi.mocked(prisma.auditLog.create).mockResolvedValue({ id: 'audit-03' } as any);

    const res = await request(app)
      .post(`/api/v1/idirs/${testIdirId}/leave`)
      .set('Authorization', `Bearer ${creatorToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.wasCreator).toBe(true);
    expect(res.body.data.remainingMembersCount).toBe(0);

    // Verify Idir was marked CLOSED and createdById cleared
    expect(prisma.idir.update).toHaveBeenCalledWith({
      where: { id: testIdirId },
      data: {
        status: 'CLOSED',
        createdById: null,
      },
    });
  });

  it('also supports leaving via /api/v1/idirs/:idirId/members/leave', async () => {
    vi.mocked(prisma.idir.findUnique).mockResolvedValue({
      id: testIdirId,
      name: 'St. George Idir',
      createdById: creatorUserId,
      memberships: [
        { id: 'm-creator', userId: creatorUserId, role: 'CHAIRPERSON', status: 'ACTIVE', joinedAt: new Date(2025, 0, 1) },
        { id: 'm-reg', userId: regularUserId, role: 'MEMBER', status: 'ACTIVE', joinedAt: new Date(2025, 1, 1) },
      ],
    } as any);

    vi.mocked(prisma.membership.findFirst).mockResolvedValue({
      id: 'm-reg',
      idirId: testIdirId,
      userId: regularUserId,
      role: 'MEMBER',
      status: 'ACTIVE',
    } as any);

    vi.mocked(prisma.contribution.count).mockResolvedValue(0);
    vi.mocked(prisma.ikubParticipant.count).mockResolvedValue(0);
    vi.mocked(prisma.membership.delete).mockResolvedValue({ id: 'm-reg' } as any);

    const res = await request(app)
      .post(`/api/v1/idirs/${testIdirId}/members/leave`)
      .set('Authorization', `Bearer ${memberToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
