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
    chatMessage: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      findUnique: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
    auditLog: { create: vi.fn() },
  } as any,
}));

describe('Real-Time Group Chat Module (Telegram & WhatsApp Level)', () => {
  const userId = 'user-member-1';
  const officerId = 'user-officer-1';
  const idirId = 'idir-uuid-1';
  let memberToken: string;
  let officerToken: string;

  beforeEach(() => {
    vi.clearAllMocks();

    memberToken = generateAccessToken({
      userId,
      phoneNumber: '+251911555555',
      isPlatformAdmin: false,
    });

    officerToken = generateAccessToken({
      userId: officerId,
      phoneNumber: '+251911777777',
      isPlatformAdmin: false,
    });

    vi.mocked(prisma.user.findUnique).mockImplementation((args: any) => {
      if (args.where?.id === userId) {
        return Promise.resolve({
          id: userId,
          phoneNumber: '+251911555555',
          fullName: 'Abebe Bikila',
          status: 'ACTIVE',
          isPlatformAdmin: false,
          preferredLanguage: 'am',
        } as any);
      }
      if (args.where?.id === officerId) {
        return Promise.resolve({
          id: officerId,
          phoneNumber: '+251911777777',
          fullName: 'Chaltu Chairperson',
          status: 'ACTIVE',
          isPlatformAdmin: false,
          preferredLanguage: 'am',
        } as any);
      }
      return Promise.resolve(null);
    });

    vi.mocked(prisma.idir.findUnique).mockResolvedValue({
      id: idirId,
      name: 'Bole Medhanealem Idir',
      status: 'ACTIVE',
    } as any);

    vi.mocked(prisma.membership.findUnique).mockImplementation((args: any) => {
      const qUserId = args.where?.idirId_userId?.userId || args.where?.id;
      if (qUserId === userId || args.where?.id === 'membership-member-1') {
        return Promise.resolve({
          id: 'membership-member-1',
          idirId,
          userId,
          role: 'MEMBER',
          status: 'ACTIVE',
          memberNumber: 'BM-005',
          user: { id: userId, fullName: 'Abebe Bikila' },
        } as any);
      }
      if (qUserId === officerId || args.where?.id === 'membership-officer-1') {
        return Promise.resolve({
          id: 'membership-officer-1',
          idirId,
          userId: officerId,
          role: 'CHAIRPERSON',
          status: 'ACTIVE',
          memberNumber: 'BM-001',
          user: { id: officerId, fullName: 'Chaltu Chairperson' },
        } as any);
      }
      return Promise.resolve(null);
    });
  });

  describe('GET /api/v1/idirs/:idirId/chat', () => {
    it('returns chat history for active members', async () => {
      const mockMessages = [
        {
          id: 'msg-1',
          idirId,
          membershipId: 'membership-member-1',
          senderId: userId,
          senderName: 'Abebe Bikila',
          senderRole: 'MEMBER',
          messageType: 'TEXT',
          content: 'Hello everyone!',
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      vi.mocked(prisma.chatMessage.findMany).mockResolvedValue(mockMessages as any);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/chat`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0].content).toBe('Hello everyone!');
    });

    it('rejects unauthenticated requests with 401', async () => {
      const res = await request(app).get(`/api/v1/idirs/${idirId}/chat`);
      expect(res.status).toBe(401);
    });

    it('blocks users who are not active members of the Idir', async () => {
      vi.mocked(prisma.membership.findUnique).mockResolvedValue(null);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/chat`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
    });
  });

  describe('POST /api/v1/idirs/:idirId/chat (Text, Replies, Deduplication)', () => {
    it('allows an active member to send a text message', async () => {
      vi.mocked(prisma.chatMessage.create).mockResolvedValue({
        id: 'msg-2',
        idirId,
        membershipId: 'membership-member-1',
        senderId: userId,
        senderName: 'Abebe Bikila',
        senderRole: 'MEMBER',
        messageType: 'TEXT',
        content: 'Condolences to the family',
        createdAt: new Date(),
        updatedAt: new Date(),
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/chat`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({ content: 'Condolences to the family' });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.content).toBe('Condolences to the family');
    });

    it('supports replying to a specific message', async () => {
      vi.mocked(prisma.chatMessage.create).mockResolvedValue({
        id: 'msg-reply',
        idirId,
        content: 'I agree completely',
        replyToId: 'msg-2',
        replyToSenderName: 'Abebe Bikila',
        replyToContent: 'Condolences to the family',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/chat`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          content: 'I agree completely',
          replyToId: '00000000-0000-0000-0000-000000000002',
          replyToSenderName: 'Abebe Bikila',
          replyToContent: 'Condolences to the family',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
    });

    it('idempotently handles retries with clientMutationId', async () => {
      const existing = {
        id: 'msg-existing',
        idirId,
        content: 'Retried message',
        clientMutationId: 'mutation-token-123',
      };
      vi.mocked(prisma.chatMessage.findFirst).mockResolvedValue(existing as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/chat`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          content: 'Retried message',
          clientMutationId: 'mutation-token-123',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.id).toBe('msg-existing');
      expect(prisma.chatMessage.create).not.toHaveBeenCalled();
    });

    it('rejects ordinary member attempting to broadcast ANNOUNCEMENT with 403', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/chat`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          content: 'Important Announcement',
          messageType: 'ANNOUNCEMENT',
        });

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('Only Idir leaders and officers can broadcast');
    });

    it('allows chairperson to broadcast official ANNOUNCEMENT', async () => {
      vi.mocked(prisma.chatMessage.create).mockResolvedValue({
        id: 'msg-announcement',
        idirId,
        messageType: 'ANNOUNCEMENT',
        content: 'Official Meeting this Sunday',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/chat`)
        .set('Authorization', `Bearer ${officerToken}`)
        .send({
          content: 'Official Meeting this Sunday',
          messageType: 'ANNOUNCEMENT',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
    });
  });

  describe('Pinning, Reactions, and Moderation', () => {
    it('allows leadership to pin a message', async () => {
      vi.mocked(prisma.chatMessage.findUnique).mockResolvedValue({
        id: 'msg-to-pin',
        idirId,
        isPinned: false,
      } as any);
      vi.mocked(prisma.chatMessage.update).mockResolvedValue({
        id: 'msg-to-pin',
        isPinned: true,
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/chat/msg-to-pin/pin`)
        .set('Authorization', `Bearer ${officerToken}`)
        .send({ isPinned: true });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('forbids ordinary member from pinning a message with 403', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/chat/msg-to-pin/pin`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({ isPinned: true });

      expect(res.status).toBe(403);
    });

    it('allows member to add an emoji reaction', async () => {
      vi.mocked(prisma.chatMessage.findUnique).mockResolvedValue({
        id: 'msg-react',
        idirId,
        reactions: [],
      } as any);
      vi.mocked(prisma.chatMessage.update).mockResolvedValue({
        id: 'msg-react',
        reactions: [{ emoji: '👍', userId, userName: 'Abebe Bikila' }],
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/chat/msg-react/react`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({ emoji: '👍', action: 'add' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('allows admin to delete any inappropriate message for moderation', async () => {
      vi.mocked(prisma.chatMessage.findUnique).mockResolvedValue({
        id: 'msg-inappropriate',
        idirId,
        senderId: 'other-user-uuid',
      } as any);

      const res = await request(app)
        .delete(`/api/v1/idirs/${idirId}/chat/msg-inappropriate`)
        .set('Authorization', `Bearer ${officerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('Attachment Upload Validation', () => {
    it('validates and accepts valid document/image payload', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/chat/upload`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          fileName: 'bylaws.pdf',
          fileType: 'application/pdf',
          fileSize: 1024 * 50,
          base64Data: 'JVBERi0xLjQKJ...',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.attachmentType).toBe('PDF');
      expect(res.body.data.attachmentName).toBe('bylaws.pdf');
    });

    it('rejects unsupported file formats with 400 Bad Request', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/chat/upload`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          fileName: 'malware.exe',
          fileType: 'application/x-msdownload',
          fileSize: 1024,
          base64Data: 'TVqQAAMAAAA...',
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toContain('Unsupported file format');
    });
  });
});
