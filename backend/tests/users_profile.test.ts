import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/config/database.js';
import { generateAccessToken } from '../src/shared/utils/jwt.js';

vi.mock('../src/config/database.js', () => ({
  prisma: {
    user: {
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      update: vi.fn(),
    },
  } as any,
}));

describe('User Profile Management & Strict Email Immutability Tests', () => {
  const userId = 'user-test-uuid-1';
  const otherUserId = 'user-other-uuid-2';
  let token: string;

  const mockUser = {
    id: userId,
    fullName: 'Almaz Ayana',
    phoneNumber: '+251911000001',
    email: 'almaz@example.com',
    address: 'Bole Subcity, Woreda 03',
    dateOfBirth: new Date('1990-05-15T00:00:00.000Z'),
    preferredLanguage: 'am',
    status: 'ACTIVE',
    isPlatformAdmin: false,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-02T00:00:00.000Z'),
    memberships: [],
  };

  beforeEach(() => {
    vi.clearAllMocks();

    token = generateAccessToken({
      userId,
      phoneNumber: '+251911000001',
      isPlatformAdmin: false,
    });

    vi.mocked(prisma.user.findUnique).mockImplementation((args: any) => {
      if (args.where?.id === userId) {
        return Promise.resolve(mockUser as any);
      }
      return Promise.resolve(null);
    });
  });

  describe('GET /api/v1/users/me', () => {
    it('returns full user profile details', async () => {
      const res = await request(app)
        .get('/api/v1/users/me')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.id).toBe(userId);
      expect(res.body.data.fullName).toBe('Almaz Ayana');
      expect(res.body.data.email).toBe('almaz@example.com');
      expect(res.body.data.address).toBe('Bole Subcity, Woreda 03');
      expect(res.body.data.preferredLanguage).toBe('am');
    });

    it('rejects unauthenticated request with 401', async () => {
      const res = await request(app).get('/api/v1/users/me');
      expect(res.status).toBe(401);
    });
  });

  describe('PATCH /api/v1/users/me Profile Updates', () => {
    it('allows updating fullName, phoneNumber, address, and preferredLanguage', async () => {
      vi.mocked(prisma.user.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.user.update).mockResolvedValue({
        ...mockUser,
        fullName: 'Almaz Ayana Updated',
        phoneNumber: '+251911000002',
        address: 'Yeka Subcity, Woreda 08',
        preferredLanguage: 'om',
      } as any);

      const res = await request(app)
        .patch('/api/v1/users/me')
        .set('Authorization', `Bearer ${token}`)
        .send({
          fullName: 'Almaz Ayana Updated',
          phoneNumber: '+251911000002',
          address: 'Yeka Subcity, Woreda 08',
          preferredLanguage: 'om',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(prisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: userId },
          data: expect.objectContaining({
            fullName: 'Almaz Ayana Updated',
            phoneNumber: '+251911000002',
            address: 'Yeka Subcity, Woreda 08',
            preferredLanguage: 'om',
          }),
        })
      );
      // Ensure email is NEVER in update data
      const updateCall = vi.mocked(prisma.user.update).mock.calls[0][0];
      expect(updateCall.data).not.toHaveProperty('email');
    });

    it('allows updating profile via PUT /api/v1/users/me', async () => {
      vi.mocked(prisma.user.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.user.update).mockResolvedValue({
        ...mockUser,
        fullName: 'Almaz Ayana PUT',
      } as any);

      const res = await request(app)
        .put('/api/v1/users/me')
        .set('Authorization', `Bearer ${token}`)
        .send({
          fullName: 'Almaz Ayana PUT',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('allows updating profile via PUT /api/v1/users/:userId matching current user', async () => {
      vi.mocked(prisma.user.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.user.update).mockResolvedValue({
        ...mockUser,
        fullName: 'Almaz Ayana By ID',
      } as any);

      const res = await request(app)
        .put(`/api/v1/users/${userId}`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          fullName: 'Almaz Ayana By ID',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('Strict Email Immutability Enforcement', () => {
    it('REJECTS any attempt to change email with 400 Bad Request', async () => {
      const res = await request(app)
        .patch('/api/v1/users/me')
        .set('Authorization', `Bearer ${token}`)
        .send({
          fullName: 'Almaz Ayana',
          email: 'newemail@example.com',
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('Email address cannot be changed');
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('succeeds when existing email is echoed back unchanged', async () => {
      vi.mocked(prisma.user.update).mockResolvedValue({
        ...mockUser,
        fullName: 'Almaz Ayana Renamed',
      } as any);

      const res = await request(app)
        .patch('/api/v1/users/me')
        .set('Authorization', `Bearer ${token}`)
        .send({
          fullName: 'Almaz Ayana Renamed',
          email: 'almaz@example.com', // identical to existing
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      // Ensure email was not added to Prisma update payload
      const updateCall = vi.mocked(prisma.user.update).mock.calls[0][0];
      expect(updateCall.data).not.toHaveProperty('email');
    });
  });

  describe('Security & Access Controls', () => {
    it('rejects changing phone number if already used by another user (409 Conflict)', async () => {
      vi.mocked(prisma.user.findFirst).mockResolvedValue({
        id: otherUserId,
        phoneNumber: '+251911999999',
      } as any);

      const res = await request(app)
        .patch('/api/v1/users/me')
        .set('Authorization', `Bearer ${token}`)
        .send({
          phoneNumber: '+251911999999',
        });

      expect(res.status).toBe(409);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('Phone number is already in use');
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('prohibits updating another user profile (403 Forbidden)', async () => {
      const res = await request(app)
        .patch(`/api/v1/users/${otherUserId}`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          fullName: 'Malicious Change',
        });

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('You can only update your own profile');
      expect(prisma.user.update).not.toHaveBeenCalled();
    });
  });
});

