import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/config/database.js';
import { generateAccessToken } from '../src/shared/utils/jwt.js';
import { assertIdirActive } from '../src/middleware/assertIdirActive.js';

vi.mock('../src/config/database.js', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    membership: { findUnique: vi.fn(), findFirst: vi.fn() },
    idir: { findUnique: vi.fn() },
    contribution: { create: vi.fn() },
    expense: { create: vi.fn() },
    assistanceCase: { create: vi.fn() },
    ikubPayout: { create: vi.fn() },
  },
}));

describe('Stage 3: Lock Money & Claim Features until ACTIVE (assertIdirActive)', () => {
  const userId = 'user-officer-uuid-1';
  const idirId = '00000000-0000-0000-0000-000000000001';
  const nonActiveStatuses = ['DRAFT', 'SUSPENDED', 'CLOSED', 'INACTIVE', 'ARCHIVED'] as const;
  let token: string;

  beforeEach(() => {
    vi.clearAllMocks();

    token = generateAccessToken({
      userId,
      phoneNumber: '+251911333333',
      isPlatformAdmin: false,
    });

    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: userId,
      phoneNumber: '+251911333333',
      fullName: 'Chairperson Officer',
      status: 'ACTIVE',
      isPlatformAdmin: false,
      preferredLanguage: 'am',
    } as any);

    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-uuid-1',
      idirId,
      userId,
      role: 'CHAIRPERSON',
      status: 'ACTIVE',
      memberNumber: 'CP-001',
    } as any);
  });

  describe('Direct assertIdirActive helper tests', () => {
    it.each(nonActiveStatuses)(
      'assertIdirActive blocks %s status with ForbiddenError',
      async (status) => {
        vi.mocked(prisma.idir.findUnique).mockResolvedValue({
          id: idirId,
          name: 'Community Idir',
          status,
        } as any);

        await expect(assertIdirActive(idirId)).rejects.toThrow(
          /Financial and claim operations are locked because this Idir is in/
        );
      }
    );

    it('assertIdirActive passes when Idir status is ACTIVE', async () => {
      vi.mocked(prisma.idir.findUnique).mockResolvedValue({
        id: idirId,
        name: 'Active Community Idir',
        status: 'ACTIVE',
      } as any);

      await expect(assertIdirActive(idirId)).resolves.toBeUndefined();
    });

    it('assertIdirActive throws NotFoundError when Idir does not exist', async () => {
      vi.mocked(prisma.idir.findUnique).mockResolvedValue(null);

      await expect(assertIdirActive('non-existent-id')).rejects.toThrow(
        /Idir not found/
      );
    });
  });

  describe('Route-level enforcement on all money & claim endpoints', () => {
    describe('Contribution endpoints', () => {
      it.each(nonActiveStatuses)(
        'blocks POST /contributions when status is %s',
        async (status) => {
          vi.mocked(prisma.idir.findUnique).mockResolvedValue({
            id: idirId,
            name: 'Draft Idir',
            status,
          } as any);

          const res = await request(app)
            .post(`/api/v1/idirs/${idirId}/contributions`)
            .set('Authorization', `Bearer ${token}`)
            .send({
              memberId: 'member-1',
              typeId: 'type-1',
              amount: 250,
              paymentMethod: 'CASH',
            });

          expect(res.status).toBe(403);
          expect(res.body.success).toBe(false);
          expect(res.body.error.code).toBe('FORBIDDEN');
          expect(res.body.error.message).toContain(
            `Available once this Idir is active`
          );
        }
      );
    });

    describe('Expense endpoints', () => {
      it.each(nonActiveStatuses)(
        'blocks POST /expenses when status is %s',
        async (status) => {
          vi.mocked(prisma.idir.findUnique).mockResolvedValue({
            id: idirId,
            name: 'Draft Idir',
            status,
          } as any);

          const res = await request(app)
            .post(`/api/v1/idirs/${idirId}/expenses`)
            .set('Authorization', `Bearer ${token}`)
            .send({
              title: 'Tent repair',
              amount: 500,
              category: 'EQUIPMENT',
              expenseDate: new Date().toISOString(),
            });

          expect(res.status).toBe(403);
          expect(res.body.success).toBe(false);
          expect(res.body.error.code).toBe('FORBIDDEN');
          expect(res.body.error.message).toContain(
            `Available once this Idir is active`
          );
        }
      );
    });

    describe('Assistance & Claim endpoints', () => {
      it.each(nonActiveStatuses)(
        'blocks POST /assistance/cases when status is %s',
        async (status) => {
          vi.mocked(prisma.idir.findUnique).mockResolvedValue({
            id: idirId,
            name: 'Draft Idir',
            status,
          } as any);

          const res = await request(app)
            .post(`/api/v1/idirs/${idirId}/assistance/cases`)
            .set('Authorization', `Bearer ${token}`)
            .send({
              memberId: 'member-1',
              assistanceType: 'FUNERAL',
              deceasedFullName: 'Test Deceased',
              incidentDate: new Date().toISOString(),
            });

          expect(res.status).toBe(403);
          expect(res.body.success).toBe(false);
          expect(res.body.error.code).toBe('FORBIDDEN');
          expect(res.body.error.message).toContain(
            `Available once this Idir is active`
          );
        }
      );
    });

    describe('Ikub payout money endpoints', () => {
      it.each(nonActiveStatuses)(
        'blocks POST /ikub/groups/.../payouts when status is %s',
        async (status) => {
          vi.mocked(prisma.idir.findUnique).mockResolvedValue({
            id: idirId,
            name: 'Draft Idir',
            status,
          } as any);

          const res = await request(app)
            .post(
              `/api/v1/idirs/${idirId}/ikub/groups/00000000-0000-0000-0000-000000000010/payouts`
            )
            .set('Authorization', `Bearer ${token}`)
            .send({
              roundId: '00000000-0000-0000-0000-000000000020',
              winnerParticipantId: '00000000-0000-0000-0000-000000000030',
              grossAmount: 10000,
              paymentMethod: 'TELEBIRR',
            });

          expect(res.status).toBe(403);
          expect(res.body.success).toBe(false);
          expect(res.body.error.code).toBe('FORBIDDEN');
          expect(res.body.error.message).toContain(
            `Available once this Idir is active`
          );
        }
      );
    });
  });
});
