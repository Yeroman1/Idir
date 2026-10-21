import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/config/database.js';
import { generateAccessToken } from '../src/shared/utils/jwt.js';

vi.mock('../src/config/database.js', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    idir: { create: vi.fn() },
    idirSettings: { create: vi.fn() },
    contributionType: { create: vi.fn() },
    membership: { create: vi.fn() },
    auditLog: { create: vi.fn() },
    $transaction: vi.fn((callback) => callback(prisma)),
  },
}));

describe('Idir Creation & Fayda Verification Tests', () => {
  const verifiedUserId = 'verified-user-uuid';
  const unverifiedUserId = 'unverified-user-uuid';
  let verifiedToken: string;
  let unverifiedToken: string;

  beforeEach(() => {
    vi.clearAllMocks();

    verifiedToken = generateAccessToken({
      userId: verifiedUserId,
      phoneNumber: '+251911111111',
      isPlatformAdmin: false,
    });

    unverifiedToken = generateAccessToken({
      userId: unverifiedUserId,
      phoneNumber: '+251922222222',
      isPlatformAdmin: false,
    });
  });

  it('rejects unverified user (lacks Fayda ID) with 403 Forbidden', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: unverifiedUserId,
      phoneNumber: '+251922222222',
      fullName: 'Unverified User',
      email: null,
      faydaId: null,
      status: 'ACTIVE',
      isPlatformAdmin: false,
      preferredLanguage: 'am',
    } as any);

    const res = await request(app)
      .post('/api/v1/idirs')
      .set('Authorization', `Bearer ${unverifiedToken}`)
      .send({
        name: 'Bole Medhanealem Idir',
        community: 'Bole Subcity',
        location: 'Addis Ababa',
        purpose: 'Community funeral and mutual aid fund',
        contributionAmount: 250,
        contributionFrequency: 'MONTHLY',
      });

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('FORBIDDEN');
    expect(res.body.error.message).toContain('Fayda verification is required');
  });

  it('rejects unauthenticated user with 401 Unauthorized', async () => {
    const res = await request(app)
      .post('/api/v1/idirs')
      .send({
        name: 'Bole Medhanealem Idir',
        community: 'Bole Subcity',
        location: 'Addis Ababa',
        purpose: 'Community funeral and mutual aid fund',
        contributionAmount: 250,
        contributionFrequency: 'MONTHLY',
      });

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('rejects request when fields are missing and returns per-field validation errors', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: verifiedUserId,
      phoneNumber: '+251911111111',
      fullName: 'Verified Chairperson',
      email: 'chair@example.com',
      faydaId: '100020003001',
      status: 'ACTIVE',
      isPlatformAdmin: false,
      preferredLanguage: 'am',
    } as any);

    // Empty payload missing all required fields
    const res = await request(app)
      .post('/api/v1/idirs')
      .set('Authorization', `Bearer ${verifiedToken}`)
      .send({});

    expect(res.status).toBe(422);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');

    const details = res.body.error.details as Array<{ field: string; message: string }>;
    expect(details).toBeDefined();

    const fieldsWithErrors = details.map((d) => d.field);
    expect(fieldsWithErrors).toContain('name');
    expect(fieldsWithErrors).toContain('community');
    expect(fieldsWithErrors).toContain('location');
    expect(fieldsWithErrors).toContain('purpose');
    expect(fieldsWithErrors).toContain('contributionAmount');
    expect(fieldsWithErrors).toContain('contributionFrequency');
  });

  it('rejects contributionAmount <= 0 with per-field error', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: verifiedUserId,
      phoneNumber: '+251911111111',
      fullName: 'Verified Chairperson',
      email: 'chair@example.com',
      faydaId: '100020003001',
      status: 'ACTIVE',
      isPlatformAdmin: false,
      preferredLanguage: 'am',
    } as any);

    const res = await request(app)
      .post('/api/v1/idirs')
      .set('Authorization', `Bearer ${verifiedToken}`)
      .send({
        name: 'Bole Medhanealem Idir',
        community: 'Bole Subcity',
        location: 'Addis Ababa',
        purpose: 'Community funeral and mutual aid fund',
        contributionAmount: -50,
        contributionFrequency: 'MONTHLY',
      });

    expect(res.status).toBe(422);
    expect(res.body.success).toBe(false);
    const details = res.body.error.details as Array<{ field: string; message: string }>;
    const amountError = details.find((d) => d.field === 'contributionAmount');
    expect(amountError).toBeDefined();
    expect(amountError?.message).toContain('greater than 0');
  });

  it('saves valid request as DRAFT even if client sends status ACTIVE', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: verifiedUserId,
      phoneNumber: '+251911111111',
      fullName: 'Verified Chairperson',
      email: 'chair@example.com',
      faydaId: '100020003001',
      status: 'ACTIVE',
      isPlatformAdmin: false,
      preferredLanguage: 'am',
    } as any);

    const createdIdirMock = {
      id: 'idir-draft-uuid-1',
      name: 'Yeka Karalo Idir',
      community: 'Yeka Subcity',
      location: 'Addis Ababa',
      purpose: 'Neighborhood mutual assistance and funeral cover',
      contributionAmount: 200,
      contributionFrequency: 'MONTHLY',
      status: 'DRAFT',
      createdById: verifiedUserId,
      currency: 'ETB',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      createdBy: {
        id: verifiedUserId,
        fullName: 'Verified Chairperson',
        phoneNumber: '+251911111111',
        faydaId: '100020003001',
      },
    };

    vi.mocked(prisma.idir.create).mockResolvedValue(createdIdirMock as any);
    vi.mocked(prisma.idirSettings.create).mockResolvedValue({ id: 'settings-1' } as any);
    vi.mocked(prisma.contributionType.create).mockResolvedValue({ id: 'type-1' } as any);
    vi.mocked(prisma.membership.create).mockResolvedValue({
      id: 'membership-1',
      idirId: createdIdirMock.id,
      userId: verifiedUserId,
      role: 'CHAIRPERSON',
      status: 'ACTIVE',
    } as any);
    vi.mocked(prisma.auditLog.create).mockResolvedValue({ id: 'audit-1' } as any);

    const res = await request(app)
      .post('/api/v1/idirs')
      .set('Authorization', `Bearer ${verifiedToken}`)
      .send({
        name: 'Yeka Karalo Idir',
        community: 'Yeka Subcity',
        location: 'Addis Ababa',
        purpose: 'Neighborhood mutual assistance and funeral cover',
        contributionAmount: 200,
        contributionFrequency: 'MONTHLY',
        status: 'ACTIVE', // Client attempts to force ACTIVE
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe('DRAFT');

    // Verify prisma.idir.create was called with status: 'DRAFT'
    expect(prisma.idir.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          name: 'Yeka Karalo Idir',
          status: 'DRAFT',
          createdById: verifiedUserId,
        }),
      })
    );
  });
});
