import crypto from 'crypto';
import { Prisma } from '@prisma/client';
import { prisma } from '../../config/database.js';
import {
  NotFoundError,
  BadRequestError,
  ForbiddenError,
} from '../../shared/errors/AppError.js';
import {
  CreateCaseInput,
  SubmitRequestInput,
  ReviewRequestInput,
  DisburseInput,
} from './assistance.validation.js';

export class AssistanceService {
  async createCase(idirId: string, input: CreateCaseInput, actorId: string) {
    const membership = await prisma.membership.findFirst({
      where: { id: input.membershipId, idirId, status: 'ACTIVE' },
    });
    if (!membership) {
      throw new NotFoundError('Active member not found in this Idir');
    }

    const assistanceCase = await prisma.assistanceCase.create({
      data: {
        idirId,
        membershipId: input.membershipId,
        caseType: input.caseType || 'FUNERAL',
        title: input.title,
        description: input.description,
        deceasedName: input.deceasedName,
        deceasedRelation: input.deceasedRelation,
        isConfidential: input.isConfidential ?? false,
        status: 'OPEN',
      },
      include: {
        membership: {
          include: {
            user: { select: { id: true, fullName: true, phoneNumber: true } },
          },
        },
      },
    });

    await prisma.auditLog.create({
      data: {
        actorId,
        idirId,
        action: 'CREATE_ASSISTANCE_CASE',
        entityType: 'AssistanceCase',
        entityId: assistanceCase.id,
        safeMetadata: {
          caseType: assistanceCase.caseType,
          title: assistanceCase.title,
          isConfidential: assistanceCase.isConfidential,
        },
      },
    });

    return assistanceCase;
  }

  async listCases(
    idirId: string,
    params: {
      page?: number;
      limit?: number;
      membershipId?: string;
      caseType?: CreateCaseInput['caseType'];
      status?: 'OPEN' | 'IN_REVIEW' | 'APPROVED' | 'REJECTED' | 'CLOSED';
    },
    userContext: { userId: string; role?: string; isPlatformAdmin?: boolean }
  ) {
    const page = Number(params.page) || 1;
    const limit = Number(params.limit) || 20;
    const skip = (page - 1) * limit;

    const isPrivileged =
      userContext.isPlatformAdmin ||
      ['CHAIRPERSON', 'TREASURER', 'SECRETARY', 'COMMITTEE', 'AUDITOR'].includes(
        userContext.role || ''
      );

    const where: Prisma.AssistanceCaseWhereInput = {
      idirId,
      ...(params.membershipId && { membershipId: params.membershipId }),
      ...(params.caseType && { caseType: params.caseType }),
      ...(params.status && { status: params.status }),
      // Confidential cases only visible to privileged roles or the applicant member
      ...(!isPrivileged && {
        OR: [{ isConfidential: false }, { membership: { userId: userContext.userId } }],
      }),
    };

    const [total, cases] = await Promise.all([
      prisma.assistanceCase.count({ where }),
      prisma.assistanceCase.findMany({
        where,
        skip,
        take: limit,
        orderBy: { openedAt: 'desc' },
        include: {
          membership: {
            include: {
              user: { select: { id: true, fullName: true, phoneNumber: true } },
            },
          },
          requests: {
            include: {
              disbursements: true,
            },
          },
        },
      }),
    ]);

    return {
      items: cases,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getCaseById(
    idirId: string,
    caseId: string,
    userContext: { userId: string; role?: string; isPlatformAdmin?: boolean }
  ) {
    const assistanceCase = await prisma.assistanceCase.findFirst({
      where: { id: caseId, idirId },
      include: {
        membership: {
          include: {
            user: { select: { id: true, fullName: true, phoneNumber: true } },
          },
        },
        requests: {
          include: {
            submittedBy: { select: { id: true, fullName: true } },
            reviewedBy: { select: { id: true, fullName: true } },
            disbursements: {
              include: {
                recordedBy: { select: { id: true, fullName: true } },
              },
            },
          },
        },
      },
    });

    if (!assistanceCase) {
      throw new NotFoundError('Assistance case not found');
    }

    const isPrivileged =
      userContext.isPlatformAdmin ||
      ['CHAIRPERSON', 'TREASURER', 'SECRETARY', 'COMMITTEE', 'AUDITOR'].includes(
        userContext.role || ''
      );

    if (
      assistanceCase.isConfidential &&
      !isPrivileged &&
      assistanceCase.membership.userId !== userContext.userId
    ) {
      throw new ForbiddenError('Access to this confidential assistance case is restricted');
    }

    return assistanceCase;
  }

  async submitRequest(
    idirId: string,
    caseId: string,
    input: SubmitRequestInput,
    actorId: string
  ) {
    const assistanceCase = await prisma.assistanceCase.findFirst({
      where: { id: caseId, idirId },
    });
    if (!assistanceCase) {
      throw new NotFoundError('Assistance case not found');
    }

    if (assistanceCase.status === 'CLOSED' || assistanceCase.status === 'REJECTED') {
      throw new BadRequestError(`Cannot submit requests for a ${assistanceCase.status} case`);
    }

    const request = await prisma.assistanceRequest.create({
      data: {
        caseId,
        requestedAmount: new Prisma.Decimal(input.requestedAmount),
        currency: 'ETB',
        justification: input.justification,
        submittedById: actorId,
        status: 'PENDING',
      },
      include: {
        submittedBy: { select: { id: true, fullName: true } },
      },
    });

    // Update case status to IN_REVIEW if OPEN
    if (assistanceCase.status === 'OPEN') {
      await prisma.assistanceCase.update({
        where: { id: caseId },
        data: { status: 'IN_REVIEW' },
      });
    }

    return request;
  }

  async reviewRequest(
    idirId: string,
    caseId: string,
    requestId: string,
    input: ReviewRequestInput,
    actorId: string,
    actorMembershipId?: string
  ) {
    const request = await prisma.assistanceRequest.findFirst({
      where: { id: requestId, caseId, case: { idirId } },
      include: { case: true },
    });

    if (!request) {
      throw new NotFoundError('Assistance request not found');
    }

    if (request.status !== 'PENDING') {
      throw new BadRequestError(`Cannot review a request that is already ${request.status}`);
    }

    // INSECURE DESIGN FIX: Strict Self-Approval Ban (Bylaws Rule & STRIDE E-02)
    if (
      request.submittedById === actorId ||
      (actorMembershipId && request.case.membershipId === actorMembershipId)
    ) {
      throw new ForbiddenError(
        'Self-approval is strictly forbidden: officers cannot review or approve their own assistance requests'
      );
    }

    const newStatus = input.approved ? 'APPROVED' : 'REJECTED';

    return prisma.$transaction(async (tx) => {
      const updated = await tx.assistanceRequest.update({
        where: { id: requestId },
        data: {
          status: newStatus,
          reviewedById: actorId,
          reviewedAt: new Date(),
          reviewNotes: input.reviewNotes,
        },
      });

      if (input.approved) {
        await tx.assistanceCase.update({
          where: { id: caseId },
          data: { status: 'APPROVED' },
        });
      }

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: input.approved ? 'APPROVE_ASSISTANCE_REQUEST' : 'REJECT_ASSISTANCE_REQUEST',
          entityType: 'AssistanceRequest',
          entityId: requestId,
          safeMetadata: {
            caseId,
            status: newStatus,
            amount: request.requestedAmount.toString(),
          },
        },
      });

      return updated;
    });
  }

  async recordDisbursement(
    idirId: string,
    requestId: string,
    input: DisburseInput,
    actorId: string
  ) {
    const request = await prisma.assistanceRequest.findFirst({
      where: { id: requestId, case: { idirId } },
      include: { disbursements: true },
    });

    if (!request) {
      throw new NotFoundError('Assistance request not found');
    }

    if (request.status !== 'APPROVED') {
      throw new BadRequestError('Cannot disburse funds for an unapproved assistance request');
    }

    // INSECURE DESIGN FIX: Submitter cannot disburse funds to themselves
    if (request.submittedById === actorId) {
      throw new ForbiddenError(
        'Self-disbursement is strictly forbidden: the submitter of this assistance request cannot disburse funds to themselves'
      );
    }

    const dateStr = new Date().toISOString().slice(2, 10).replace(/-/g, '');
    const randomSuffix = crypto.randomBytes(3).toString('hex').toUpperCase();
    const receiptNumber = `DISB-${dateStr}-${randomSuffix}`;

    return prisma.$transaction(async (tx) => {
      const disbursement = await tx.assistanceDisbursement.create({
        data: {
          requestId,
          idirId,
          amount: new Prisma.Decimal(input.amount),
          currency: 'ETB',
          recipientName: input.recipientName,
          recipientPhone: input.recipientPhone,
          paymentMethod: input.paymentMethod || 'CASH',
          paymentReference: input.paymentReference,
          receiptNumber,
          recordedById: actorId,
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'DISBURSE_ASSISTANCE',
          entityType: 'AssistanceDisbursement',
          entityId: disbursement.id,
          safeMetadata: {
            requestId,
            amount: input.amount,
            recipientName: input.recipientName,
            receiptNumber,
          },
        },
      });

      return disbursement;
    });
  }
}

export const assistanceService = new AssistanceService();
