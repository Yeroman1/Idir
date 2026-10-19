import { Prisma } from '@prisma/client';
import { prisma } from '../../config/database.js';
import {
  NotFoundError,
  ConflictError,
  BadRequestError,
} from '../../shared/errors/AppError.js';
import {
  CreateIkubGroupInput,
  AddParticipantInput,
  CreateRoundInput,
  RecordIkubContributionInput,
  RecordIkubPayoutInput,
} from './ikub.validation.js';

export class IkubService {
  async createGroup(idirId: string, input: CreateIkubGroupInput, actorId: string) {
    const group = await prisma.ikubGroup.create({
      data: {
        idirId,
        name: input.name,
        description: input.description,
        contributionAmount: new Prisma.Decimal(input.contributionAmount),
        currency: 'ETB',
        frequency: input.frequency || 'WEEKLY',
        startDate: new Date(input.startDate),
        totalRounds: input.totalRounds || 10,
        payoutRule: input.payoutRule || 'LOTTERY',
        status: 'ACTIVE',
      },
    });

    await prisma.auditLog.create({
      data: {
        actorId,
        idirId,
        action: 'CREATE_IKUB_GROUP',
        entityType: 'IkubGroup',
        entityId: group.id,
        safeMetadata: { name: group.name, amount: input.contributionAmount },
      },
    });

    return group;
  }

  async listGroups(
    idirId: string,
    params: { page?: number; limit?: number; status?: 'DRAFT' | 'ACTIVE' | 'COMPLETED' | 'CANCELLED' }
  ) {
    const page = Number(params.page) || 1;
    const limit = Number(params.limit) || 20;
    const skip = (page - 1) * limit;

    const where: Prisma.IkubGroupWhereInput = {
      idirId,
      ...(params.status && { status: params.status }),
    };

    const [total, groups] = await Promise.all([
      prisma.ikubGroup.count({ where }),
      prisma.ikubGroup.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          _count: {
            select: {
              participants: true,
              rounds: true,
            },
          },
        },
      }),
    ]);

    return {
      items: groups.map((g) => ({
        ...g,
        participantsCount: g._count.participants,
        roundsCount: g._count.rounds,
      })),
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getGroupById(idirId: string, groupId: string) {
    const group = await prisma.ikubGroup.findFirst({
      where: { id: groupId, idirId },
      include: {
        participants: {
          include: {
            membership: {
              include: {
                user: { select: { id: true, fullName: true, phoneNumber: true } },
              },
            },
          },
        },
        rounds: {
          orderBy: { roundNumber: 'asc' },
          include: {
            payout: {
              include: {
                recipientParticipant: {
                  include: {
                    membership: {
                      include: {
                        user: { select: { fullName: true } },
                      },
                    },
                  },
                },
              },
            },
            _count: {
              select: { contributions: true },
            },
          },
        },
      },
    });

    if (!group) {
      throw new NotFoundError('Ikub group not found');
    }

    return group;
  }

  async addParticipant(
    idirId: string,
    groupId: string,
    input: AddParticipantInput,
    actorId: string
  ) {
    const group = await prisma.ikubGroup.findFirst({
      where: { id: groupId, idirId },
    });
    if (!group) {
      throw new NotFoundError('Ikub group not found');
    }

    const membership = await prisma.membership.findFirst({
      where: { id: input.membershipId, idirId, status: 'ACTIVE' },
    });
    if (!membership) {
      throw new NotFoundError('Active member not found in this Idir');
    }

    const existingParticipant = await prisma.ikubParticipant.findUnique({
      where: {
        ikubGroupId_membershipId: {
          ikubGroupId: groupId,
          membershipId: input.membershipId,
        },
      },
    });
    if (existingParticipant) {
      throw new ConflictError('Member is already a participant in this Ikub group');
    }

    const participant = await prisma.ikubParticipant.create({
      data: {
        ikubGroupId: groupId,
        membershipId: input.membershipId,
        payoutOrder: input.payoutOrder,
        status: 'ACTIVE',
      },
      include: {
        membership: {
          include: {
            user: { select: { fullName: true, phoneNumber: true } },
          },
        },
      },
    });

    await prisma.auditLog.create({
      data: {
        actorId,
        idirId,
        action: 'ADD_IKUB_PARTICIPANT',
        entityType: 'IkubParticipant',
        entityId: participant.id,
        safeMetadata: { groupId, membershipId: input.membershipId },
      },
    });

    return participant;
  }

  async createRound(idirId: string, groupId: string, input: CreateRoundInput, actorId: string) {
    const group = await prisma.ikubGroup.findFirst({
      where: { id: groupId, idirId },
    });
    if (!group) {
      throw new NotFoundError('Ikub group not found');
    }

    const existingRound = await prisma.ikubRound.findUnique({
      where: {
        ikubGroupId_roundNumber: {
          ikubGroupId: groupId,
          roundNumber: input.roundNumber,
        },
      },
    });
    if (existingRound) {
      throw new ConflictError(`Round ${input.roundNumber} already exists in this Ikub group`);
    }

    const round = await prisma.ikubRound.create({
      data: {
        ikubGroupId: groupId,
        roundNumber: input.roundNumber,
        scheduledDate: new Date(input.scheduledDate),
        recipientParticipantId: input.recipientParticipantId,
        status: 'SCHEDULED',
      },
    });

    await prisma.auditLog.create({
      data: {
        actorId,
        idirId,
        action: 'CREATE_IKUB_ROUND',
        entityType: 'IkubRound',
        entityId: round.id,
        safeMetadata: { groupId, roundNumber: round.roundNumber },
      },
    });

    return round;
  }

  async recordContribution(
    idirId: string,
    groupId: string,
    input: RecordIkubContributionInput,
    actorId: string
  ) {
    // Idempotency check for mobile sync
    if (input.clientMutationId) {
      const existing = await prisma.ikubContribution.findUnique({
        where: { clientMutationId: input.clientMutationId },
      });
      if (existing) {
        return existing;
      }
    }

    const round = await prisma.ikubRound.findFirst({
      where: { id: input.roundId, ikubGroupId: groupId, ikubGroup: { idirId } },
    });
    if (!round) {
      throw new NotFoundError('Ikub round not found in this group');
    }

    const participant = await prisma.ikubParticipant.findFirst({
      where: { id: input.participantId, ikubGroupId: groupId, status: 'ACTIVE' },
    });
    if (!participant) {
      throw new NotFoundError('Active participant not found in this Ikub group');
    }

    // Check for duplicate contribution for this participant in this round
    const existing = await prisma.ikubContribution.findUnique({
      where: {
        roundId_participantId: {
          roundId: input.roundId,
          participantId: input.participantId,
        },
      },
    });
    if (existing) {
      throw new ConflictError(
        'Contribution for this participant in this round has already been recorded'
      );
    }

    const contribution = await prisma.ikubContribution.create({
      data: {
        roundId: input.roundId,
        participantId: input.participantId,
        amount: new Prisma.Decimal(input.amount),
        currency: 'ETB',
        status: 'CONFIRMED',
        paymentMethod: input.paymentMethod || 'CASH',
        paymentReference: input.paymentReference,
        recordedById: actorId,
        clientMutationId: input.clientMutationId,
      },
      include: {
        participant: {
          include: {
            membership: {
              include: { user: { select: { fullName: true } } },
            },
          },
        },
      },
    });

    await prisma.auditLog.create({
      data: {
        actorId,
        idirId,
        action: 'RECORD_IKUB_CONTRIBUTION',
        entityType: 'IkubContribution',
        entityId: contribution.id,
        safeMetadata: {
          groupId,
          roundId: input.roundId,
          amount: input.amount,
        },
      },
    });

    return contribution;
  }

  async recordPayout(
    idirId: string,
    groupId: string,
    input: RecordIkubPayoutInput,
    actorId: string
  ) {
    const round = await prisma.ikubRound.findFirst({
      where: { id: input.roundId, ikubGroupId: groupId, ikubGroup: { idirId } },
      include: { payout: true },
    });
    if (!round) {
      throw new NotFoundError('Ikub round not found');
    }

    // Prevent duplicate payouts for the round
    if (round.payout) {
      throw new ConflictError(`Round ${round.roundNumber} has already been paid out`);
    }

    const participant = await prisma.ikubParticipant.findFirst({
      where: { id: input.recipientParticipantId, ikubGroupId: groupId, status: 'ACTIVE' },
    });
    if (!participant) {
      throw new NotFoundError('Recipient participant not found in this Ikub group');
    }

    if (participant.hasWonPayout) {
      throw new ConflictError(
        'This participant has already won an Ikub payout in this cycle'
      );
    }

    // Atomic transaction: Record payout, mark participant won, complete round
    return prisma.$transaction(async (tx) => {
      const payout = await tx.ikubPayout.create({
        data: {
          roundId: input.roundId,
          recipientParticipantId: input.recipientParticipantId,
          amount: new Prisma.Decimal(input.amount),
          currency: 'ETB',
          status: 'CONFIRMED',
          paymentMethod: input.paymentMethod || 'CASH',
          paymentReference: input.paymentReference,
          approvedById: actorId,
          recordedById: actorId,
        },
        include: {
          recipientParticipant: {
            include: {
              membership: {
                include: { user: { select: { fullName: true, phoneNumber: true } } },
              },
            },
          },
        },
      });

      // Mark participant as having won
      await tx.ikubParticipant.update({
        where: { id: input.recipientParticipantId },
        data: { hasWonPayout: true },
      });

      // Mark round completed
      await tx.ikubRound.update({
        where: { id: input.roundId },
        data: {
          status: 'COMPLETED',
          completedAt: new Date(),
          recipientParticipantId: input.recipientParticipantId,
        },
      });

      // Emit Audit Log
      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'RECORD_IKUB_PAYOUT',
          entityType: 'IkubPayout',
          entityId: payout.id,
          safeMetadata: {
            groupId,
            roundId: input.roundId,
            recipientId: input.recipientParticipantId,
            amount: input.amount,
          },
        },
      });

      return payout;
    });
  }

  async getGroupSummary(idirId: string, groupId: string) {
    const group = await prisma.ikubGroup.findFirst({
      where: { id: groupId, idirId },
    });
    if (!group) {
      throw new NotFoundError('Ikub group not found');
    }

    // Segregated financial calculation for Ikub
    const [contribAgg, payoutAgg, participantsCount, completedRoundsCount] =
      await Promise.all([
        prisma.ikubContribution.aggregate({
          where: { round: { ikubGroupId: groupId }, status: 'CONFIRMED' },
          _sum: { amount: true },
        }),
        prisma.ikubPayout.aggregate({
          where: { round: { ikubGroupId: groupId }, status: 'CONFIRMED' },
          _sum: { amount: true },
        }),
        prisma.ikubParticipant.count({
          where: { ikubGroupId: groupId, status: 'ACTIVE' },
        }),
        prisma.ikubRound.count({
          where: { ikubGroupId: groupId, status: 'COMPLETED' },
        }),
      ]);

    const totalCollected = contribAgg._sum.amount ? Number(contribAgg._sum.amount) : 0;
    const totalPaidOut = payoutAgg._sum.amount ? Number(payoutAgg._sum.amount) : 0;
    const remainingPool = totalCollected - totalPaidOut;

    return {
      groupId: group.id,
      name: group.name,
      currency: group.currency,
      activeParticipants: participantsCount,
      completedRounds: completedRoundsCount,
      totalRounds: group.totalRounds,
      financials: {
        totalCollected,
        totalPaidOut,
        remainingPool,
      },
    };
  }
}

export const ikubService = new IkubService();
