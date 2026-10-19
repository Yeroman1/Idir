import crypto from 'crypto';
import { Prisma } from '@prisma/client';
import { prisma } from '../../config/database.js';
import {
  NotFoundError,
  BadRequestError,
  ConflictError,
} from '../../shared/errors/AppError.js';
import {
  CreateContributionTypeInput,
  RecordContributionInput,
  ReverseContributionInput,
} from './contributions.validation.js';

export class ContributionsService {
  async createType(idirId: string, input: CreateContributionTypeInput, actorId?: string) {
    const contributionType = await prisma.contributionType.create({
      data: {
        idirId,
        name: input.name,
        description: input.description,
        defaultAmount: input.defaultAmount ? new Prisma.Decimal(input.defaultAmount) : null,
        isMandatory: input.isMandatory ?? true,
        isActive: true,
      },
    });

    if (actorId) {
      await prisma.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'CREATE_CONTRIBUTION_TYPE',
          entityType: 'ContributionType',
          entityId: contributionType.id,
          safeMetadata: { name: contributionType.name },
        },
      });
    }

    return contributionType;
  }

  async listTypes(idirId: string) {
    return prisma.contributionType.findMany({
      where: { idirId, isActive: true },
      orderBy: { createdAt: 'asc' },
    });
  }

  async recordContribution(
    idirId: string,
    input: RecordContributionInput,
    actorId: string
  ) {
    // 1. Idempotency check for offline mobile sync
    if (input.clientMutationId) {
      const existing = await prisma.contribution.findUnique({
        where: { clientMutationId: input.clientMutationId },
        include: {
          membership: { include: { user: { select: { fullName: true, phoneNumber: true } } } },
          contributionType: true,
        },
      });
      if (existing) {
        // Return already created record without creating a duplicate
        return existing;
      }
    }

    // 2. Validate membership belongs to this Idir
    const membership = await prisma.membership.findFirst({
      where: { id: input.membershipId, idirId, status: 'ACTIVE' },
    });
    if (!membership) {
      throw new NotFoundError('Active member not found in this Idir');
    }

    // 3. Validate contribution type
    const contributionType = await prisma.contributionType.findFirst({
      where: { id: input.contributionTypeId, idirId, isActive: true },
    });
    if (!contributionType) {
      throw new NotFoundError('Active contribution type not found in this Idir');
    }

    // 4. Generate receipt number
    const dateStr = new Date().toISOString().slice(2, 10).replace(/-/g, '');
    const randomSuffix = crypto.randomBytes(3).toString('hex').toUpperCase();
    const receiptNumber = `REC-${dateStr}-${randomSuffix}`;

    const paymentDate = input.paymentDate ? new Date(input.paymentDate) : new Date();

    return prisma.$transaction(async (tx) => {
      const contribution = await tx.contribution.create({
        data: {
          idirId,
          membershipId: input.membershipId,
          contributionTypeId: input.contributionTypeId,
          amount: new Prisma.Decimal(input.amount),
          currency: 'ETB',
          paymentDate,
          paymentMethod: input.paymentMethod || 'CASH',
          paymentReference: input.paymentReference,
          receiptNumber,
          status: input.status || 'CONFIRMED',
          recordedById: actorId,
          confirmedById: input.status === 'CONFIRMED' ? actorId : null,
          confirmedAt: input.status === 'CONFIRMED' ? new Date() : null,
          clientMutationId: input.clientMutationId,
        },
        include: {
          membership: {
            include: {
              user: {
                select: { id: true, fullName: true, phoneNumber: true },
              },
            },
          },
          contributionType: true,
        },
      });

      // Audit Log
      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'RECORD_CONTRIBUTION',
          entityType: 'Contribution',
          entityId: contribution.id,
          safeMetadata: {
            amount: input.amount,
            receiptNumber,
            memberId: membership.id,
            status: contribution.status,
          },
        },
      });

      return contribution;
    });
  }

  async confirmContribution(idirId: string, contributionId: string, actorId: string) {
    const contribution = await prisma.contribution.findFirst({
      where: { id: contributionId, idirId },
    });

    if (!contribution) {
      throw new NotFoundError('Contribution not found');
    }

    if (contribution.status === 'CONFIRMED') {
      return contribution;
    }

    if (contribution.status === 'REVERSED') {
      throw new BadRequestError('Cannot confirm a reversed transaction');
    }

    return prisma.$transaction(async (tx) => {
      const updated = await tx.contribution.update({
        where: { id: contributionId },
        data: {
          status: 'CONFIRMED',
          confirmedById: actorId,
          confirmedAt: new Date(),
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'CONFIRM_CONTRIBUTION',
          entityType: 'Contribution',
          entityId: contributionId,
          safeMetadata: { receiptNumber: contribution.receiptNumber },
        },
      });

      return updated;
    });
  }

  async reverseContribution(
    idirId: string,
    contributionId: string,
    input: ReverseContributionInput,
    actorId: string
  ) {
    const contribution = await prisma.contribution.findFirst({
      where: { id: contributionId, idirId },
    });

    if (!contribution) {
      throw new NotFoundError('Contribution record not found');
    }

    if (contribution.isReversed || contribution.status === 'REVERSED') {
      throw new ConflictError('This transaction has already been reversed');
    }

    return prisma.$transaction(async (tx) => {
      const reversed = await tx.contribution.update({
        where: { id: contributionId },
        data: {
          isReversed: true,
          status: 'REVERSED',
          reversalReason: input.reversalReason,
          reversedAt: new Date(),
          reversedById: actorId,
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'REVERSE_CONTRIBUTION',
          entityType: 'Contribution',
          entityId: contributionId,
          safeMetadata: {
            receiptNumber: contribution.receiptNumber,
            amount: contribution.amount.toString(),
            reversalReason: input.reversalReason,
          },
        },
      });

      return reversed;
    });
  }

  async listContributions(
    idirId: string,
    params: {
      page?: number;
      limit?: number;
      membershipId?: string;
      contributionTypeId?: string;
      status?: 'PENDING' | 'CONFIRMED' | 'FAILED' | 'REVERSED';
      startDate?: string;
      endDate?: string;
    }
  ) {
    const page = Number(params.page) || 1;
    const limit = Number(params.limit) || 20;
    const skip = (page - 1) * limit;

    const where: Prisma.ContributionWhereInput = {
      idirId,
      ...(params.membershipId && { membershipId: params.membershipId }),
      ...(params.contributionTypeId && { contributionTypeId: params.contributionTypeId }),
      ...(params.status && { status: params.status }),
      ...(params.startDate || params.endDate
        ? {
            paymentDate: {
              ...(params.startDate && { gte: new Date(params.startDate) }),
              ...(params.endDate && { lte: new Date(params.endDate) }),
            },
          }
        : {}),
    };

    const [total, contributions] = await Promise.all([
      prisma.contribution.count({ where }),
      prisma.contribution.findMany({
        where,
        skip,
        take: limit,
        orderBy: { paymentDate: 'desc' },
        include: {
          membership: {
            include: {
              user: {
                select: { id: true, fullName: true, phoneNumber: true },
              },
            },
          },
          contributionType: true,
          recordedBy: {
            select: { id: true, fullName: true },
          },
        },
      }),
    ]);

    return {
      items: contributions,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getContributionById(idirId: string, contributionId: string) {
    const contribution = await prisma.contribution.findFirst({
      where: { id: contributionId, idirId },
      include: {
        membership: {
          include: {
            user: { select: { id: true, fullName: true, phoneNumber: true } },
          },
        },
        contributionType: true,
        recordedBy: { select: { id: true, fullName: true } },
        confirmedBy: { select: { id: true, fullName: true } },
        reversedBy: { select: { id: true, fullName: true } },
      },
    });

    if (!contribution) {
      throw new NotFoundError('Contribution not found');
    }

    return contribution;
  }
}

export const contributionsService = new ContributionsService();
