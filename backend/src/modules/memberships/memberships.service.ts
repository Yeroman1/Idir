import { Prisma } from '@prisma/client';
import { prisma } from '../../config/database.js';
import {
  NotFoundError,
  ConflictError,
  BadRequestError,
} from '../../shared/errors/AppError.js';
import { AddMemberInput, UpdateMemberInput } from './memberships.validation.js';

export class MembershipsService {
  async addMember(idirId: string, input: AddMemberInput, actorId?: string) {
    let targetUserId = input.userId;

    if (!targetUserId && input.phoneNumber) {
      const user = await prisma.user.findUnique({
        where: { phoneNumber: input.phoneNumber },
      });
      if (!user) {
        throw new NotFoundError(
          `No registered user found with phone number ${input.phoneNumber}. The member must register first.`
        );
      }
      targetUserId = user.id;
    }

    if (!targetUserId) {
      throw new BadRequestError('Either userId or phoneNumber must be provided');
    }

    // Check if membership already exists for this user in this Idir
    const existing = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId: targetUserId,
        },
      },
    });

    if (existing) {
      throw new ConflictError(
        'This user already has a membership record in this Idir'
      );
    }

    // Determine or validate memberNumber
    let memberNumber = input.memberNumber;
    if (!memberNumber) {
      const count = await prisma.membership.count({ where: { idirId } });
      memberNumber = `M-${String(count + 1).padStart(3, '0')}`;
    }

    const existingNumber = await prisma.membership.findUnique({
      where: {
        idirId_memberNumber: {
          idirId,
          memberNumber,
        },
      },
    });

    if (existingNumber) {
      throw new ConflictError(
        `Member number ${memberNumber} is already assigned in this Idir`
      );
    }

    const membership = await prisma.membership.create({
      data: {
        idirId,
        userId: targetUserId,
        memberNumber,
        role: input.role || 'MEMBER',
        status: 'ACTIVE',
      },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            phoneNumber: true,
            email: true,
            faydaId: true,
            preferredLanguage: true,
          },
        },
      },
    });

    if (actorId) {
      await prisma.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'ADD_MEMBER',
          entityType: 'Membership',
          entityId: membership.id,
          safeMetadata: {
            memberNumber: membership.memberNumber,
            role: membership.role,
            userId: targetUserId,
          },
        },
      });
    }

    return membership;
  }

  async listMembers(
    idirId: string,
    params: {
      page?: number;
      limit?: number;
      search?: string;
      role?: AddMemberInput['role'];
      status?: 'ACTIVE' | 'PENDING' | 'SUSPENDED' | 'DEACTIVATED';
    }
  ) {
    const page = Number(params.page) || 1;
    const limit = Number(params.limit) || 20;
    const skip = (page - 1) * limit;

    const where: Prisma.MembershipWhereInput = {
      idirId,
      ...(params.role && { role: params.role }),
      ...(params.status && { status: params.status }),
      ...(params.search && {
        OR: [
          { memberNumber: { contains: params.search, mode: 'insensitive' } },
          { user: { fullName: { contains: params.search, mode: 'insensitive' } } },
          { user: { phoneNumber: { contains: params.search } } },
        ],
      }),
    };

    const [total, members] = await Promise.all([
      prisma.membership.count({ where }),
      prisma.membership.findMany({
        where,
        skip,
        take: limit,
        orderBy: { joinedAt: 'asc' },
        include: {
          user: {
            select: {
              id: true,
              fullName: true,
              phoneNumber: true,
              email: true,
              faydaId: true,
              preferredLanguage: true,
            },
          },
        },
      }),
    ]);

    return {
      items: members,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getMemberById(idirId: string, membershipId: string) {
    const membership = await prisma.membership.findFirst({
      where: { id: membershipId, idirId },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            phoneNumber: true,
            email: true,
            faydaId: true,
            preferredLanguage: true,
            status: true,
          },
        },
        _count: {
          select: {
            contributions: true,
            ikubParticipants: true,
            meetingAttendances: true,
          },
        },
      },
    });

    if (!membership) {
      throw new NotFoundError('Membership record not found');
    }

    return membership;
  }

  async updateMember(
    idirId: string,
    membershipId: string,
    input: UpdateMemberInput,
    actorId?: string
  ) {
    const membership = await prisma.membership.findFirst({
      where: { id: membershipId, idirId },
    });

    if (!membership) {
      throw new NotFoundError('Membership record not found');
    }

    if (input.memberNumber && input.memberNumber !== membership.memberNumber) {
      const existing = await prisma.membership.findUnique({
        where: {
          idirId_memberNumber: {
            idirId,
            memberNumber: input.memberNumber,
          },
        },
      });
      if (existing) {
        throw new ConflictError(
          `Member number ${input.memberNumber} is already assigned in this Idir`
        );
      }
    }

    const updated = await prisma.membership.update({
      where: { id: membershipId },
      data: input,
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            phoneNumber: true,
          },
        },
      },
    });

    if (actorId) {
      await prisma.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'UPDATE_MEMBER',
          entityType: 'Membership',
          entityId: membershipId,
          safeMetadata: input as Prisma.InputJsonValue,
        },
      });
    }

    return updated;
  }

  async deactivateMember(idirId: string, membershipId: string, actorId?: string) {
    const membership = await prisma.membership.findFirst({
      where: { id: membershipId, idirId },
    });

    if (!membership) {
      throw new NotFoundError('Membership record not found');
    }

    const deactivated = await prisma.membership.update({
      where: { id: membershipId },
      data: { status: 'DEACTIVATED' },
    });

    if (actorId) {
      await prisma.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'DEACTIVATE_MEMBER',
          entityType: 'Membership',
          entityId: membershipId,
          safeMetadata: { previousStatus: membership.status },
        },
      });
    }

    return deactivated;
  }
}

export const membershipsService = new MembershipsService();
