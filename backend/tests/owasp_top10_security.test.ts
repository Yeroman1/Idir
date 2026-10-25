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
      create: vi.fn(),
      update: vi.fn(),
    },
    membership: {
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      findMany: vi.fn(),
      count: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
    idir: {
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      update: vi.fn(),
    },
    contribution: {
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      findMany: vi.fn(),
      count: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      aggregate: vi.fn(),
    },
    contributionType: {
      findFirst: vi.fn(),
      findMany: vi.fn(),
      create: vi.fn(),
    },
    expense: {
      findFirst: vi.fn(),
      findMany: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      aggregate: vi.fn(),
      groupBy: vi.fn(),
    },
    assistanceCase: {
      findFirst: vi.fn(),
      findMany: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      count: vi.fn(),
    },
    assistanceRequest: {
      findFirst: vi.fn(),
      findMany: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
    assistanceDisbursement: {
      create: vi.fn(),
      aggregate: vi.fn(),
    },
    auditLog: {
      create: vi.fn(),
    },
    refreshToken: {
      create: vi.fn(),
      findUnique: vi.fn(),
      update: vi.fn(),
      updateMany: vi.fn(),
    },
    $transaction: vi.fn((callback) => callback(prisma)),
  },
}));

describe('OWASP Top 10 Security Verification Tests', () => {
  const memberUserId = 'user-member-uuid';
  const officerUserId = 'user-officer-uuid';
  const idirId = '00000000-0000-0000-0000-000000000001';
  const foreignIdirId = '00000000-0000-0000-0000-000000000002';
  const memberMembershipId = 'membership-member-uuid';
  const officerMembershipId = 'membership-officer-uuid';

  let memberToken: string;
  let officerToken: string;

  beforeEach(() => {
    vi.clearAllMocks();

    memberToken = generateAccessToken({
      userId: memberUserId,
      phoneNumber: '+251911555555',
      isPlatformAdmin: false,
    });

    officerToken = generateAccessToken({
      userId: officerUserId,
      phoneNumber: '+251911111111',
      isPlatformAdmin: false,
    });

    // Default Idir is ACTIVE
    vi.mocked(prisma.idir.findUnique).mockResolvedValue({
      id: idirId,
      name: 'Bole Medhanealem Idir',
      status: 'ACTIVE',
    } as any);
  });

  // ── Scenario 1: Unauthenticated User Cannot Access Protected Resources ──────
  describe('1. Broken Access Control: Authentication Gate', () => {
    it('rejects unauthenticated requests to protected endpoints with 401 Unauthorized', async () => {
      const res = await request(app).get(`/api/v1/idirs/${idirId}/contributions`);
      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('rejects requests with malformed Bearer header with 401 Unauthorized', async () => {
      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/contributions`)
        .set('Authorization', 'NotABearerToken');
      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });
  });

  // ── Scenario 2: Ordinary Member Cannot Perform Administrator/Officer Actions ─
  describe('2. Broken Access Control: Privilege Separation Matrix', () => {
    beforeEach(() => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({
        id: memberUserId,
        status: 'ACTIVE',
        isPlatformAdmin: false,
      } as any);

      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: memberMembershipId,
        idirId,
        userId: memberUserId,
        role: 'MEMBER',
        status: 'ACTIVE',
      } as any);
    });

    it('prohibits ordinary member from recording an operating expense (403 Forbidden)', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/expenses`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({
          category: 'UTILITIES',
          amount: 500,
          description: 'Unauthorized utility payment',
        });

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('FORBIDDEN');
    });

    it('prohibits ordinary member from viewing operating expenses and receipts (403 Forbidden)', async () => {
      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/expenses`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('FORBIDDEN');
    });

    it('prohibits ordinary member from reviewing assistance requests (403 Forbidden)', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/assistance/cases/case-1/requests/req-1/review`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({ approved: true });

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('FORBIDDEN');
    });

    it('prohibits ordinary member from reversing contributions (403 Forbidden)', async () => {
      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/contributions/contrib-1/reverse`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({ reversalReason: 'Unauthorized test reversal' });

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('FORBIDDEN');
    });
  });

  // ── Scenario 3: Cross-Idir Data Isolation ────────────────────────────────────
  describe('3. Broken Access Control: Multi-Tenant Idir Isolation', () => {
    it('rejects access when user has no active membership in target Idir (403 Forbidden)', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({
        id: memberUserId,
        status: 'ACTIVE',
        isPlatformAdmin: false,
      } as any);

      // Membership lookup in foreignIdir returns null
      vi.mocked(prisma.membership.findUnique).mockResolvedValue(null);

      const res = await request(app)
        .get(`/api/v1/idirs/${foreignIdirId}/contributions`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('not an active member');
    });
  });

  // ── Scenario 4 & 5: IDOR & Horizontal Privilege Escalation Protection ───────
  describe('4. Insecure Direct Object Reference (IDOR) & Scoping Protection', () => {
    beforeEach(() => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({
        id: memberUserId,
        status: 'ACTIVE',
        isPlatformAdmin: false,
      } as any);

      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: memberMembershipId,
        idirId,
        userId: memberUserId,
        role: 'MEMBER',
        status: 'ACTIVE',
      } as any);
    });

    it('scopes listContributions strictly to requesting member membershipId when role is MEMBER', async () => {
      vi.mocked(prisma.contribution.count).mockResolvedValue(0);
      vi.mocked(prisma.contribution.findMany).mockResolvedValue([]);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/contributions`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.status).toBe(200);
      // Verify prisma.contribution.findMany was called with membershipId = memberMembershipId
      expect(prisma.contribution.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            membershipId: memberMembershipId,
          }),
        })
      );
    });

    it('prevents ordinary member from retrieving another member contribution by ID (403 Forbidden)', async () => {
      vi.mocked(prisma.contribution.findFirst).mockResolvedValue({
        id: 'contrib-foreign-id',
        idirId,
        membershipId: 'other-member-membership-uuid', // Foreign membership
        amount: 200,
      } as any);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/contributions/contrib-foreign-id`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('not authorized to view this contribution');
    });

    it('prevents ordinary member from viewing another member contribution report by ID (403 Forbidden)', async () => {
      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/reports/members/foreign-membership-uuid/contributions`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('not authorized to view another member');
    });
  });

  // ── Scenario 6: Strict Self-Approval Ban (Anti-Collusion / Anti-Fraud) ────────
  describe('5. Insecure Design: Strict Anti-Collusion Self-Approval Ban', () => {
    it('strictly forbids an officer from reviewing or approving their own assistance request', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({
        id: officerUserId,
        status: 'ACTIVE',
        isPlatformAdmin: false,
      } as any);

      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: officerMembershipId,
        idirId,
        userId: officerUserId,
        role: 'CHAIRPERSON',
        status: 'ACTIVE',
      } as any);

      // Assistance request where submittedById is the officer themselves
      vi.mocked(prisma.assistanceRequest.findFirst).mockResolvedValue({
        id: 'request-self-id',
        caseId: 'case-self-id',
        submittedById: officerUserId, // Submitter is the reviewer!
        status: 'PENDING',
        requestedAmount: 5000,
        case: {
          id: 'case-self-id',
          idirId,
          membershipId: officerMembershipId,
        },
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/assistance/cases/case-self-id/requests/request-self-id/review`)
        .set('Authorization', `Bearer ${officerToken}`)
        .send({ approved: true, reviewNotes: 'Attempting self-approval' });

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('Self-approval is strictly forbidden');
    });

    it('strictly forbids a submitter from executing disbursement to themselves', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({
        id: officerUserId,
        status: 'ACTIVE',
        isPlatformAdmin: false,
      } as any);

      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: officerMembershipId,
        idirId,
        userId: officerUserId,
        role: 'TREASURER',
        status: 'ACTIVE',
      } as any);

      vi.mocked(prisma.assistanceRequest.findFirst).mockResolvedValue({
        id: 'request-disburse-id',
        submittedById: officerUserId, // Submitter is the disburser!
        status: 'APPROVED',
        requestedAmount: 5000,
        disbursements: [],
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/assistance/requests/request-disburse-id/disburse`)
        .set('Authorization', `Bearer ${officerToken}`)
        .send({
          amount: 5000,
          recipientName: 'Officer Abebe',
          paymentMethod: 'CASH',
        });

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('Self-disbursement is strictly forbidden');
    });
  });

  // ── Scenario 7: Account Takeover Prevention in Registration ──────────────────
  describe('6. Identification & Authentication: Account Takeover Prevention', () => {
    it('rejects registration with 409 Conflict when phone number already exists', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({
        id: 'existing-user-uuid',
        phoneNumber: '+251911223344',
      } as any);

      const res = await request(app)
        .post('/api/v1/auth/register')
        .send({
          fullName: 'Attacker Attempting Overwrite',
          phoneNumber: '+251911223344',
          password: 'NewPassword123!',
        });

      expect(res.status).toBe(409);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('CONFLICT');
      expect(res.body.error.message).toContain('already exists');
    });
  });

  // ── Scenario 8: Expired or Inactive Sessions Cannot Perform Operations ────────
  describe('7. Session Security: Inactive & Suspended Account Enforcement', () => {
    it('rejects authenticated requests when user status is INACTIVE or SUSPENDED', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({
        id: memberUserId,
        status: 'SUSPENDED', // Account was suspended
        isPlatformAdmin: false,
      } as any);

      const res = await request(app)
        .get(`/api/v1/idirs/${idirId}/contributions`)
        .set('Authorization', `Bearer ${memberToken}`);

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('inactive or not found');
    });
  });

  // ── Scenario 9: Malicious Input Handling ─────────────────────────────────────
  describe('8. Injection Flaws: Schema Validation & Boundary Rejection', () => {
    it('rejects negative or non-numeric contribution amounts with 422 Validation Error', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({
        id: officerUserId,
        status: 'ACTIVE',
        isPlatformAdmin: false,
      } as any);

      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: officerMembershipId,
        idirId,
        userId: officerUserId,
        role: 'TREASURER',
        status: 'ACTIVE',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/contributions`)
        .set('Authorization', `Bearer ${officerToken}`)
        .send({
          membershipId: memberMembershipId,
          contributionTypeId: 'type-uuid-1',
          amount: -500, // Malicious negative amount
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('rejects SQL injection payloads in enum and date fields with 422 Validation Error', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue({
        id: officerUserId,
        status: 'ACTIVE',
        isPlatformAdmin: false,
      } as any);

      vi.mocked(prisma.membership.findUnique).mockResolvedValue({
        id: officerMembershipId,
        idirId,
        userId: officerUserId,
        role: 'TREASURER',
        status: 'ACTIVE',
      } as any);

      const res = await request(app)
        .post(`/api/v1/idirs/${idirId}/contributions`)
        .set('Authorization', `Bearer ${officerToken}`)
        .send({
          membershipId: memberMembershipId,
          contributionTypeId: 'type-uuid-1',
          amount: 500,
          paymentMethod: "CASH'; DROP TABLE \"User\"; --", // SQL injection payload
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });
  });
});
