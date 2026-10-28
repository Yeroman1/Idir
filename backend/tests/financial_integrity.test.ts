import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/config/database.js';
import { generateAccessToken } from '../src/shared/utils/jwt.js';

vi.mock('../src/config/database.js', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    membership: { findUnique: vi.fn(), findFirst: vi.fn() },
    contribution: {
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      findMany: vi.fn(),
      count: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      aggregate: vi.fn(),
    },
    contributionType: { findFirst: vi.fn(), findMany: vi.fn() },
    expense: {
      aggregate: vi.fn(),
      groupBy: vi.fn(),
      findFirst: vi.fn(),
      findMany: vi.fn(),
      count: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
    assistanceDisbursement: { aggregate: vi.fn(), findMany: vi.fn() },
    assistanceCase: { findMany: vi.fn() },
    ikubContribution: { aggregate: vi.fn() },
    ikubPayout: { aggregate: vi.fn() },
    ikubGroup: { count: vi.fn() },
    idir: { findUnique: vi.fn() },
    idirSettings: { findUnique: vi.fn() },
    auditLog: { create: vi.fn() },
    $transaction: vi.fn((callback) => callback(prisma)),
  },
}));

describe('Financial Integrity & Fund Separation Tests', () => {
  const userId = 'user-uuid-1';
  const idirId = '00000000-0000-0000-0000-000000000001';
  let token: string;

  beforeEach(() => {
    vi.clearAllMocks();
    token = generateAccessToken({
      userId,
      phoneNumber: '+251911222222',
      isPlatformAdmin: false,
    });

    vi.mocked(prisma.idir.findUnique).mockResolvedValue({
      id: idirId,
      name: 'Bole Medhanealem Idir',
      status: 'ACTIVE',
      currency: 'ETB',
    } as any);

    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: userId,
      phoneNumber: '+251911222222',
      fullName: 'Treasurer User',
      status: 'ACTIVE',
      isPlatformAdmin: false,
      preferredLanguage: 'am',
    } as any);

    // Default membership as TREASURER
    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-uuid-1',
      idirId,
      userId,
      role: 'TREASURER',
      memberNumber: 'BM-002',
      status: 'ACTIVE',
    } as any);
  });

  it('rejects contribution with negative or zero amount', async () => {
    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/contributions`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        membershipId: '00000000-0000-0000-0000-000000000002',
        contributionTypeId: '00000000-0000-0000-0000-000000000003',
        amount: -50,
      });

    expect(res.status).toBe(422);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('idempotently handles offline mobile sync when clientMutationId is repeated', async () => {
    const clientMutationId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

    // Mock existing transaction found with identical clientMutationId
    vi.mocked(prisma.contribution.findUnique).mockResolvedValue({
      id: 'existing-contribution-uuid',
      idirId,
      amount: '200.00',
      receiptNumber: 'REC-261019-SYNC01',
      status: 'CONFIRMED',
      clientMutationId,
    } as any);

    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/contributions`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        membershipId: '00000000-0000-0000-0000-000000000002',
        contributionTypeId: '00000000-0000-0000-0000-000000000003',
        amount: 200,
        clientMutationId,
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.id).toBe('existing-contribution-uuid');
    expect(res.body.data.receiptNumber).toBe('REC-261019-SYNC01');
    // Ensure create was NOT called again!
    expect(prisma.contribution.create).not.toHaveBeenCalled();
  });

  it('enforces strict mathematical segregation between Idir funds and Ikub pools in financial report', async () => {
    // Mock isolated aggregation numbers
    vi.mocked(prisma.contribution.aggregate).mockResolvedValue({
      _sum: { amount: '10000.00' },
      _count: { id: 50 },
    } as any);

    vi.mocked(prisma.expense.aggregate).mockResolvedValue({
      _sum: { amount: '3000.00' },
      _count: { id: 3 },
    } as any);

    vi.mocked(prisma.assistanceDisbursement.aggregate).mockResolvedValue({
      _sum: { amount: '2000.00' },
      _count: { id: 1 },
    } as any);

    vi.mocked(prisma.expense.groupBy).mockResolvedValue([]);
    vi.mocked(prisma.assistanceCase.findMany).mockResolvedValue([]);

    // Ikub Pool mocks (separate)
    vi.mocked(prisma.ikubContribution.aggregate).mockResolvedValue({
      _sum: { amount: '40000.00' },
      _count: { id: 40 },
    } as any);

    vi.mocked(prisma.ikubPayout.aggregate).mockResolvedValue({
      _sum: { amount: '36000.00' },
      _count: { id: 3 },
    } as any);

    vi.mocked(prisma.ikubGroup.count).mockResolvedValue(1);

    // Mock idir query
    (prisma as any).idir = {
      findUnique: vi.fn().mockResolvedValue({
        id: idirId,
        name: 'Bole Medhanealem Idir',
        currency: 'ETB',
      }),
    };

    const res = await request(app)
      .get(`/api/v1/idirs/${idirId}/reports/finances`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const data = res.body.data;
    // Idir Net = 10,000 - (3,000 + 2,000) = 5,000
    expect(data.idirLedger.totalContributions).toBe(10000);
    expect(data.idirLedger.totalExpenses).toBe(3000);
    expect(data.idirLedger.totalDisbursements).toBe(2000);
    expect(data.idirLedger.netBalance).toBe(5000);

    // Ikub Net = 40,000 - 36,000 = 4,000 (Completely separate!)
    expect(data.ikubLedger.totalContributions).toBe(40000);
    expect(data.ikubLedger.totalPayouts).toBe(36000);
    expect(data.ikubLedger.netPoolBalance).toBe(4000);

    // Verify Ikub balance was NOT blended into Idir Net
    expect(data.idirLedger.netBalance).not.toBe(9000);
  });

  it('blocks duplicate contribution submission with same member, amount, and date', async () => {
    const memberId = '00000000-0000-0000-0000-000000000002';
    const typeId = '00000000-0000-0000-0000-000000000003';

    vi.mocked(prisma.membership.findFirst).mockResolvedValue({
      id: memberId,
      idirId,
      status: 'ACTIVE',
    } as any);

    vi.mocked(prisma.contributionType.findFirst).mockResolvedValue({
      id: typeId,
      idirId,
      isActive: true,
    } as any);

    // Mock existing duplicate found
    vi.mocked(prisma.contribution.findFirst).mockResolvedValue({
      id: 'existing-id',
      receiptNumber: 'REC-20261028-DUP01',
      amount: '500.00',
    } as any);

    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/contributions`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        membershipId: memberId,
        contributionTypeId: typeId,
        amount: 500,
        paymentDate: '2026-10-28',
      });

    expect(res.status).toBe(409);
    expect(res.body.success).toBe(false);
    expect(res.body.error.message).toContain('Duplicate contribution record prevented');
    expect(prisma.contribution.create).not.toHaveBeenCalled();
  });

  it('allows regular MEMBER to view financial report read-only', async () => {
    const memberUserId = 'member-user-uuid';
    const memberToken = generateAccessToken({
      userId: memberUserId,
      phoneNumber: '+251911999999',
      isPlatformAdmin: false,
    });

    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: memberUserId,
      status: 'ACTIVE',
      isPlatformAdmin: false,
    } as any);

    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-regular-1',
      idirId,
      userId: memberUserId,
      role: 'MEMBER',
      status: 'ACTIVE',
    } as any);

    (prisma as any).idir = {
      findUnique: vi.fn().mockResolvedValue({
        id: idirId,
        name: 'Bole Medhanealem Idir',
        currency: 'ETB',
      }),
    };

    const res = await request(app)
      .get(`/api/v1/idirs/${idirId}/reports/finances`)
      .set('Authorization', `Bearer ${memberToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('blocks regular MEMBER from recording an expense', async () => {
    const memberUserId = 'member-user-uuid';
    const memberToken = generateAccessToken({
      userId: memberUserId,
      phoneNumber: '+251911999999',
      isPlatformAdmin: false,
    });

    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: memberUserId,
      status: 'ACTIVE',
      isPlatformAdmin: false,
    } as any);

    vi.mocked(prisma.membership.findUnique).mockResolvedValue({
      id: 'membership-regular-1',
      idirId,
      userId: memberUserId,
      role: 'MEMBER',
      status: 'ACTIVE',
    } as any);

    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/expenses`)
      .set('Authorization', `Bearer ${memberToken}`)
      .send({
        category: 'ADMINISTRATIVE',
        amount: 250,
        description: 'Office stationery unauthorized attempt',
      });

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
  });

  it('exports auditable financial report CSV with headers and period covered', async () => {
    (prisma as any).idir = {
      findUnique: vi.fn().mockResolvedValue({
        id: idirId,
        name: 'Bole Medhanealem Idir',
        currency: 'ETB',
      }),
    };

    const res = await request(app)
      .get(`/api/v1/idirs/${idirId}/reports/export?format=csv`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('text/csv');
    expect(res.text).toContain('IDIR FINANCIAL REPORT - AUDITABLE LEDGER');
    expect(res.text).toContain('Bole Medhanealem Idir');
    expect(res.text).toContain('--- EXECUTIVE SUMMARY ---');
  });

  it('reverses an expense and records audit log without altering original record', async () => {
    const expenseId = 'expense-uuid-1';
    vi.mocked(prisma.expense.findFirst).mockResolvedValue({
      id: expenseId,
      idirId,
      amount: '500.00',
      category: 'VENUE',
      status: 'APPROVED',
    } as any);

    vi.mocked(prisma.expense.update).mockResolvedValue({
      id: expenseId,
      status: 'REJECTED',
      rejectionReason: '[REVERSED]: Duplicate receipt submitted',
    } as any);

    const res = await request(app)
      .post(`/api/v1/idirs/${idirId}/expenses/${expenseId}/reverse`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        reversalReason: 'Duplicate receipt submitted',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(prisma.expense.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: expenseId },
        data: expect.objectContaining({
          status: 'REJECTED',
          rejectionReason: expect.stringContaining('Duplicate receipt submitted'),
        }),
      })
    );
    expect(prisma.auditLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          action: 'REVERSE_EXPENSE',
          entityType: 'Expense',
          entityId: expenseId,
        }),
      })
    );
  });
});
