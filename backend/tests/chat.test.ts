import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/config/database.js';
import { generateAccessToken } from '../src/shared/utils/jwt.js';

vi.mock('../src/config/database.js', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    membership: { findUnique: vi.fn(), findFirst: vi.fn() },
    idir: { findUnique: vi.fn() },
    chatMessage: { findMany: vi.fn(), create: vi.fn() },
  } as any,
}));

describe('Real-Time Group Chat Module', () => {
  const userId = 'user-member-1';
  const idirId = 'idir-uuid-1';
  let token: string;

  beforeEach(() => {
    vi.clearAllMocks();

    token = generateAccessToken({
      userId,
      phoneNumber: '+251911555555',
      isPlatformAdmin: false,
    });

    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: userId,
      phoneNumber: '+251911555555',
      fullName: 'Abebe Bikila',
      status: 'ACTIVE',
      isPlatformAdmin: false,
      preferredLanguage: 'am',
    } as any);

    vi.mocked(prisma.idir.findUnique).mockResolvedValue({
      id: idirId,
      name: 'Bole Medhanealem Idir',
      status: 'ACTIVE',
    } as any);

    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-uuid-1',
      idirId,
      userId,
      role: 'MEMBER',
      status: 'ACTIVE',
      memberNumber: 'BM-005',
      user: {
        id: userId,
        fullName: 'Abebe Bikila',
      },
    } as any);
  });

  describe('GET /api/v1/idirs/:idirId/chat', () => {
    it('returns chat history for active members', async () => {
      const mockMessages = [
        {
          id: 'msg-1',
          idirId,
          membershipId: 'membership-uuid-1',
          senderId: userId,
          senderName: 'Abebe Bikila',
          senderRole: 'MEMBER',
          content: 'Hello everyone!',
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      vi.mocked(prisma.chatMessage.findMany).mockResolvedValue(mockMessages as any);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/chat`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0].content).toBe('Hello everyone!');
    });

    it('rejects unauthenticated requests', async () => {
      const res = await request(app).get(`/api/v1/idirs/${idirId}/chat`);
      expect(res.status).toBe(401);
    });

    it('blocks users who are not active members of the Idir', async () => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue(null);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/chat`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
    });

    it('blocks suspended members from viewing messages', async () => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: 'membership-uuid-1',
        idirId,
        userId,
        status: 'SUSPENDED',
      } as any);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/chat`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
    });
  });

  describe('POST /api/v1/idirs/:idirId/chat', () => {
    it('allows an active member to send a message', async () => {
      vi.mocked(prisma.chatMessage.create).mockResolvedValue({
        id: 'msg-2',
        idirId,
        membershipId: 'membership-uuid-1',
        senderId: userId,
        senderName: 'Abebe Bikila',
        senderRole: 'MEMBER',
        content: 'Condolences to the family',
        createdAt: new Date(),
        updatedAt: new Date(),
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/chat`)
        .set('Authorization', `Bearer ${token}`)
        .send({ content: 'Condolences to the family' });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.content).toBe('Condolences to the family');
      expect(prisma.chatMessage.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            idirId,
            senderId: userId,
            senderName: 'Abebe Bikila',
            content: 'Condolences to the family',
          }),
        })
      );
    });

    it('rejects empty messages', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/chat`)
        .set('Authorization', `Bearer ${token}`)
        .send({ content: '   ' });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
    });
  });
});
