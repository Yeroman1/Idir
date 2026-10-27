import { Prisma } from '@prisma/client';
import { prisma } from '../../config/database.js';
import { NotFoundError } from '../../shared/errors/AppError.js';
import { CreateIdirInput, UpdateIdirInput, UpdateSettingsInput } from './idirs.validation.js';

export class IdirsService {
  async createIdir(creatorUserId: string, input: CreateIdirInput) {
    return prisma.$transaction(async (tx) => {
      // 1. Create Idir
      const idir = await tx.idir.create({
        data: {
          name: input.name,
          description: input.description,
          region: input.region,
          zone: input.zone,
          woreda: input.woreda,
          kebele: input.kebele,
          address: input.address,
          contactPhone: input.contactPhone,
          contactEmail: input.contactEmail,
          currency: input.currency || 'ETB',
          status: 'ACTIVE',
          createdById: creatorUserId,
        },
      });

      // 2. Create Default Settings
      await tx.idirSettings.create({
        data: {
          idirId: idir.id,
          regularDuesAmount: new Prisma.Decimal(100.0),
          duesFrequency: 'MONTHLY',
          latePaymentGraceDays: 15,
          meetingFrequency: 'MONTHLY',
          allowIkub: true,
          requireMultiApproval: true,
        },
      });

      // 3. Create Default Regular Dues Contribution Type
      await tx.contributionType.create({
        data: {
          idirId: idir.id,
          name: 'Regular Monthly Dues',
          description: 'Standard monthly membership dues',
          defaultAmount: new Prisma.Decimal(100.0),
          isMandatory: true,
          isActive: true,
        },
      });

      // 4. Assign creator as CHAIRPERSON membership
      const membership = await tx.membership.create({
        data: {
          idirId: idir.id,
          userId: creatorUserId,
          memberNumber: 'IDIR-001',
          role: 'CHAIRPERSON',
          status: 'ACTIVE',
        },
      });

      // 5. Emit Audit Log
      await tx.auditLog.create({
        data: {
          actorId: creatorUserId,
          idirId: idir.id,
          action: 'CREATE_IDIR',
          entityType: 'Idir',
          entityId: idir.id,
          safeMetadata: { name: idir.name, region: idir.region },
        },
      });

      return { ...idir, membership };
    });
  }

  async listIdirs(params: {
    page?: number;
    limit?: number;
    search?: string;
    region?: string;
    userId?: string;
  }) {
    const page = Number(params.page) || 1;
    const limit = Number(params.limit) || 20;
    const skip = (page - 1) * limit;

    const where: Prisma.IdirWhereInput = {
      ...(params.search && {
        OR: [
          { name: { contains: params.search, mode: 'insensitive' } },
          { description: { contains: params.search, mode: 'insensitive' } },
          { region: { contains: params.search, mode: 'insensitive' } },
        ],
      }),
      ...(params.region && { region: { equals: params.region, mode: 'insensitive' } }),
      ...(params.userId && {
        OR: [
          { createdById: params.userId },
          { memberships: { some: { userId: params.userId, status: 'ACTIVE' } } },
        ],
      }),
    };

    const [total, idirs] = await Promise.all([
      prisma.idir.count({ where }),
      prisma.idir.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          settings: true,
          _count: {
            select: {
              memberships: { where: { status: 'ACTIVE' } },
            },
          },
        },
      }),
    ]);

    return {
      items: idirs.map((idir) => ({
        ...idir,
        activeMembersCount: idir._count.memberships,
      })),
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getIdirById(idirId: string) {
    const idir = await prisma.idir.findUnique({
      where: { id: idirId },
      include: {
        settings: true,
        contributionTypes: { where: { isActive: true } },
        _count: {
          select: {
            memberships: { where: { status: 'ACTIVE' } },
            contributions: true,
            expenses: true,
            ikubGroups: true,
          },
        },
      },
    });

    if (!idir) {
      throw new NotFoundError('Idir not found');
    }

    return {
      ...idir,
      activeMembersCount: idir._count.memberships,
    };
  }

  async updateIdir(idirId: string, input: UpdateIdirInput, actorId?: string) {
    const existing = await prisma.idir.findUnique({ where: { id: idirId } });
    if (!existing) {
      throw new NotFoundError('Idir not found');
    }

    const updated = await prisma.idir.update({
      where: { id: idirId },
      data: input,
    });

    if (actorId) {
      await prisma.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'UPDATE_IDIR',
          entityType: 'Idir',
          entityId: idirId,
          safeMetadata: input as Prisma.InputJsonValue,
        },
      });
    }

    return updated;
  }

  async updateSettings(idirId: string, input: UpdateSettingsInput, actorId?: string) {
    const existing = await prisma.idirSettings.findUnique({ where: { idirId } });
    if (!existing) {
      throw new NotFoundError('Idir settings not found');
    }

    const updated = await prisma.idirSettings.update({
      where: { idirId },
      data: {
        ...(input.regularDuesAmount !== undefined && {
          regularDuesAmount: new Prisma.Decimal(input.regularDuesAmount),
        }),
        ...(input.duesFrequency !== undefined && { duesFrequency: input.duesFrequency }),
        ...(input.latePaymentGraceDays !== undefined && {
          latePaymentGraceDays: input.latePaymentGraceDays,
        }),
        ...(input.meetingFrequency !== undefined && { meetingFrequency: input.meetingFrequency }),
        ...(input.allowIkub !== undefined && { allowIkub: input.allowIkub }),
        ...(input.maxAssistancePerYear !== undefined && {
          maxAssistancePerYear: input.maxAssistancePerYear
            ? new Prisma.Decimal(input.maxAssistancePerYear)
            : null,
        }),
        ...(input.requireMultiApproval !== undefined && {
          requireMultiApproval: input.requireMultiApproval,
        }),
      },
    });

    if (actorId) {
      await prisma.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'UPDATE_IDIR_SETTINGS',
          entityType: 'IdirSettings',
          entityId: existing.id,
          safeMetadata: input as Prisma.InputJsonValue,
        },
      });
    }

    return updated;
  }
}

export const idirsService = new IdirsService();
