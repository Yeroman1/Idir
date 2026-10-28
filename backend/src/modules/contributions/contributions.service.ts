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

    // 4. Check for duplicate contribution record (business deduplication)
    const paymentDate = input.paymentDate ? new Date(input.paymentDate) : new Date();
    const startOfDay = new Date(paymentDate);
    startOfDay.setUTCHours(0, 0, 0, 0);
    const endOfDay = new Date(paymentDate);
    endOfDay.setUTCHours(23, 59, 59, 999);

    const duplicate = await prisma.contribution.findFirst({
      where: {
        idirId,
        membershipId: input.membershipId,
        contributionTypeId: input.contributionTypeId,
        amount: new Prisma.Decimal(input.amount),
        isReversed: false,
        paymentDate: {
          gte: startOfDay,
          lte: endOfDay,
        },
        ...(input.paymentReference ? { paymentReference: input.paymentReference } : {}),
      },
    });

    if (duplicate) {
      throw new ConflictError(
        `Duplicate contribution record prevented: A record (#${duplicate.receiptNumber}) already exists for this member, amount, and date.`
      );
    }

    // 5. Generate receipt number
    const dateStr = new Date().toISOString().slice(2, 10).replace(/-/g, '');
    const randomSuffix = crypto.randomBytes(3).toString('hex').toUpperCase();
    const receiptNumber = `REC-${dateStr}-${randomSuffix}`;

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

  async getDuesStatus(idirId: string, targetMembershipId?: string) {
    const idir = await prisma.idir.findUnique({
      where: { id: idirId },
      include: { settings: true },
    });
    if (!idir) {
      throw new NotFoundError('Idir not found');
    }

    const regularDuesAmount = idir.settings?.regularDuesAmount
      ? Number(idir.settings.regularDuesAmount)
      : 100;
    const graceDays = idir.settings?.latePaymentGraceDays ?? 15;

    const whereMembership: Prisma.MembershipWhereInput = {
      idirId,
      status: 'ACTIVE',
      ...(targetMembershipId ? { id: targetMembershipId } : {}),
    };

    const memberships = await prisma.membership.findMany({
      where: whereMembership,
      include: {
        user: { select: { id: true, fullName: true, phoneNumber: true } },
        contributions: {
          where: { isReversed: false, status: 'CONFIRMED' },
          select: { amount: true, paymentDate: true },
        },
      },
      orderBy: { memberNumber: 'asc' },
    });

    const now = new Date();
    const currentYear = now.getFullYear();
    const currentMonth = now.getMonth();

    let totalExpected = 0;
    let totalPaid = 0;
    let totalOutstanding = 0;

    const memberStatuses = memberships.map((m) => {
      const totalMemberPaid = m.contributions.reduce(
        (sum, c) => sum + Number(c.amount),
        0
      );

      const joinDate = new Date(m.joinedAt);
      const monthsSinceJoin = Math.max(
        1,
        (currentYear - joinDate.getFullYear()) * 12 + (currentMonth - joinDate.getMonth()) + 1
      );
      const cycles = Math.min(12, Math.max(1, monthsSinceJoin));
      const expectedDues = cycles * regularDuesAmount;

      const outstanding = Math.max(0, expectedDues - totalMemberPaid);
      const balance = totalMemberPaid - expectedDues;

      let status: 'PAID' | 'PARTIALLY_PAID' | 'OVERDUE' | 'EXPECTED';
      if (outstanding <= 0) {
        status = 'PAID';
      } else if (totalMemberPaid > 0) {
        status = 'PARTIALLY_PAID';
      } else {
        const dayOfMonth = now.getDate();
        if (dayOfMonth > graceDays) {
          status = 'OVERDUE';
        } else {
          status = 'EXPECTED';
        }
      }

      totalExpected += expectedDues;
      totalPaid += totalMemberPaid;
      totalOutstanding += outstanding;

      return {
        membershipId: m.id,
        memberNumber: m.memberNumber,
        fullName: m.user.fullName,
        phoneNumber: m.user.phoneNumber,
        regularDuesAmount,
        expectedDues,
        totalPaid: totalMemberPaid,
        outstanding,
        balance,
        status,
        lastPaymentDate:
          m.contributions.length > 0
            ? m.contributions[m.contributions.length - 1].paymentDate
            : null,
      };
    });

    return {
      idirId,
      currency: idir.currency || 'ETB',
      summary: {
        totalExpected,
        totalPaid,
        totalOutstanding,
        activeMembersCount: memberships.length,
        paidCount: memberStatuses.filter((s) => s.status === 'PAID').length,
        partiallyPaidCount: memberStatuses.filter((s) => s.status === 'PARTIALLY_PAID').length,
        overdueCount: memberStatuses.filter((s) => s.status === 'OVERDUE').length,
        expectedCount: memberStatuses.filter((s) => s.status === 'EXPECTED').length,
      },
      members: memberStatuses,
    };
  }
}

export const contributionsService = new ContributionsService();
