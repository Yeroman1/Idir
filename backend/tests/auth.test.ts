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

describe('Auth Module & Security Tests', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('rejects registration with invalid phone number', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        fullName: 'Test User',
        phoneNumber: 'invalid-phone',
        password: 'Password123!',
      });

    expect(res.status).toBe(422);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details).toBeDefined();
  });

  it('rejects registration with short password (< 6 chars)', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        fullName: 'Test User',
        phoneNumber: '+251911223344',
        password: '123',
      });

    expect(res.status).toBe(422);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('registers a new user successfully and returns access & refresh tokens', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(null);
    vi.mocked(prisma.user.create).mockResolvedValue({
      id: 'test-user-uuid',
      fullName: 'Abebe Kebede',
      phoneNumber: '+251911223344',
      email: 'abebe@example.com',
      preferredLanguage: 'am',
      faydaId: '100020003001',
      status: 'ACTIVE',
      isPlatformAdmin: false,
      createdAt: new Date(),
    } as any);
    vi.mocked(prisma.refreshToken.create).mockResolvedValue({} as any);

    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        fullName: 'Abebe Kebede',
        phoneNumber: '+251911223344',
        password: 'Password123!',
        email: 'abebe@example.com',
        preferredLanguage: 'am',
        faydaId: '100020003001',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.phoneNumber).toBe('+251911223344');
    expect(res.body.data.tokens.accessToken).toBeDefined();
    expect(res.body.data.tokens.refreshToken).toBeDefined();
  });

  it('authenticates valid login and issues rotating refresh tokens', async () => {
    const passwordHash = await hashPassword('Password123!');
    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: 'test-user-uuid',
      fullName: 'Abebe Kebede',
      phoneNumber: '+251911223344',
      email: 'abebe@example.com',
      passwordHash,
      preferredLanguage: 'am',
      faydaId: null,
      status: 'ACTIVE',
      isPlatformAdmin: false,
      createdAt: new Date(),
    } as any);
    vi.mocked(prisma.refreshToken.create).mockResolvedValue({} as any);

    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({
        phoneNumber: '+251911223344',
        password: 'Password123!',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.tokens.accessToken).toBeDefined();
    expect(res.body.data.tokens.refreshToken).toBeDefined();
  });

  it('rejects login with wrong password', async () => {
    const passwordHash = await hashPassword('Password123!');
    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: 'test-user-uuid',
      phoneNumber: '+251911223344',
      passwordHash,
      status: 'ACTIVE',
    } as any);

    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({
        phoneNumber: '+251911223344',
        password: 'WrongPassword!',
      });

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });
});
