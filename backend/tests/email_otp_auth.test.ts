import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/config/database.js';
import { hashPassword } from '../src/shared/utils/password.js';

vi.mock('../src/config/database.js', () => ({
  prisma: {
    user: {
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
    refreshToken: {
      create: vi.fn(),
      findUnique: vi.fn(),
      update: vi.fn(),
      updateMany: vi.fn(),
    },
    membership: {
      findUnique: vi.fn(),
      findMany: vi.fn(),
    },
  },
}));

describe('Backend Native Email OTP Authentication Flow', () => {
  const testEmail = `test.beta.${Date.now()}@example.com`;
  const testPassword = 'StrongP@ssw0rd123!';
  let devOtpCode = '';
  let registrationToken = '';

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('Step 1: POST /api/v1/auth/email/send-otp generates and dispatches OTP', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(null);

    const res = await request(app)
      .post('/api/v1/auth/email/send-otp')
      .send({ email: testEmail });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.email).toBe(testEmail);
    expect(res.body.data.devOtp).toBeDefined();
    expect(res.body.data.devOtp).toMatch(/^\d{6}$/);

    devOtpCode = res.body.data.devOtp;
  });

  it('Step 2a: POST /api/v1/auth/email/verify-otp rejects invalid OTP code', async () => {
    const res = await request(app)
      .post('/api/v1/auth/email/verify-otp')
      .send({ email: testEmail, otp: '000000' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  it('Step 2b: POST /api/v1/auth/email/verify-otp verifies valid OTP and issues registrationToken', async () => {
    const res = await request(app)
      .post('/api/v1/auth/email/verify-otp')
      .send({ email: testEmail, otp: devOtpCode });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.registrationToken).toBeDefined();

    registrationToken = res.body.data.registrationToken;
  });

  it('Step 3a: POST /api/v1/auth/email/complete-registration rejects weak password', async () => {
    const res = await request(app)
      .post('/api/v1/auth/email/complete-registration')
      .send({
        email: testEmail,
        registrationToken,
        password: 'weak',
      });

    expect(res.status).toBe(422);
    expect(res.body.success).toBe(false);
  });

  it('Step 3b: POST /api/v1/auth/email/complete-registration creates user and returns JWT tokens', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(null);
    vi.mocked(prisma.user.create).mockResolvedValue({
      id: 'mock-user-uuid',
      fullName: 'Beta Tester',
      phoneNumber: '+251911223344',
      email: testEmail,
      preferredLanguage: 'am',
      faydaId: null,
      status: 'ACTIVE',
      isPlatformAdmin: false,
      createdAt: new Date(),
      memberships: [],
    } as any);
    vi.mocked(prisma.refreshToken.create).mockResolvedValue({} as any);

    const res = await request(app)
      .post('/api/v1/auth/email/complete-registration')
      .send({
        email: testEmail,
        registrationToken,
        firstName: 'Abebe',
        middleName: 'Kebede',
        lastName: 'Bekele',
        phoneNumber: '+251911223344',
        address: 'Bole Subcity, Woreda 03, Addis Ababa',
        dateOfBirth: '1995-05-15',
        password: testPassword,
        confirmPassword: testPassword,
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user).toBeDefined();
    expect(res.body.data.user.email).toBe(testEmail);
    expect(res.body.data.tokens.accessToken).toBeDefined();
    expect(res.body.data.tokens.refreshToken).toBeDefined();
  });

  it('Step 4: POST /api/v1/auth/email/login authenticates with email and password', async () => {
    const passwordHash = await hashPassword(testPassword);
    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: 'mock-user-uuid',
      fullName: 'Beta Tester',
      phoneNumber: '+251911223344',
      email: testEmail,
      passwordHash,
      preferredLanguage: 'am',
      status: 'ACTIVE',
      isPlatformAdmin: false,
      createdAt: new Date(),
      memberships: [],
    } as any);
    vi.mocked(prisma.refreshToken.create).mockResolvedValue({} as any);

    const res = await request(app)
      .post('/api/v1/auth/email/login')
      .send({
        email: testEmail,
        password: testPassword,
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.email).toBe(testEmail);
    expect(res.body.data.tokens.accessToken).toBeDefined();
  });
});
