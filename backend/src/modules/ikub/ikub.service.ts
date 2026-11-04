import crypto from 'crypto';
import { Prisma } from '@prisma/client';
import { prisma } from '../../config/database.js';
import {
  NotFoundError,
  ConflictError,
  BadRequestError,
  ForbiddenError,
} from '../../shared/errors/AppError.js';
import {
  CreateIkubGroupInput,
  AddParticipantInput,
  CreateRoundInput,
  RecordIkubContributionInput,
  RecordIkubPayoutInput,
  DrawLotteryInput,
} from './ikub.validation.js';

export class IkubService {
  async createGroup(idirId: string, input: CreateIkubGroupInput, actorId: string) {
    return prisma.$transaction(async (tx) => {
      // 1. Enforce Singleton Active Ikub constraint per Idir
      const activeExisting = await tx.ikubGroup.findFirst({
        where: { idirId, status: { in: ['ACTIVE', 'DRAFT'] } },
      });
      if (activeExisting) {
        throw new ConflictError(
          `An active Ikub group ("${activeExisting.name}") already exists for this Idir. Complete or cancel it before starting a new one.`
        );
      }

      const totalRounds = input.totalRounds || 10;
      const start = new Date(input.startDate);

      // 2. Auto-generate all scheduled rounds based on frequency
      const roundsData: Prisma.IkubRoundCreateManyIkubGroupInput[] = [];
      for (let i = 1; i <= totalRounds; i++) {
        const roundDate = new Date(start);
        if (input.frequency === 'WEEKLY') {
          roundDate.setDate(start.getDate() + (i - 1) * 7);
        } else if (input.frequency === 'BIWEEKLY') {
          roundDate.setDate(start.getDate() + (i - 1) * 14);
        } else {
          roundDate.setMonth(start.getMonth() + (i - 1));
        }

        roundsData.push({
          roundNumber: i,
          scheduledDate: roundDate,
          status: i === 1 ? 'IN_PROGRESS' : 'SCHEDULED',
        });
      }

      const group = await tx.ikubGroup.create({
        data: {
          idirId,
          name: input.name,
          description: input.description,
          contributionAmount: new Prisma.Decimal(input.contributionAmount),
          currency: 'ETB',
          frequency: input.frequency || 'WEEKLY',
          startDate: start,
          totalRounds,
          payoutRule: input.payoutRule || 'LOTTERY',
          winnersPerRound: input.winnersPerRound || 1,
          drawMode: input.drawMode || 'DIGITAL_LOTTERY',
          status: 'ACTIVE',
          rounds: {
            createMany: {
              data: roundsData,
            },
          },
        },
        include: {
          rounds: {
            orderBy: { roundNumber: 'asc' },
          },
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'CREATE_IKUB_GROUP',
          entityType: 'IkubGroup',
          entityId: group.id,
          safeMetadata: {
            name: group.name,
            amount: input.contributionAmount,
            totalRounds,
            winnersPerRound: input.winnersPerRound || 1,
          },
        },
      });

      return group;
    });
  }

  async getActiveGroup(idirId: string) {
    const group = await prisma.ikubGroup.findFirst({
      where: { idirId, status: 'ACTIVE' },
      include: {
        participants: {
          where: { status: 'ACTIVE' },
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
            payouts: {
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
        _count: {
          select: { participants: true, rounds: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!group) return null;

    const currentRound =
      group.rounds.find((r) => r.status === 'IN_PROGRESS') ||
      group.rounds.find((r) => r.status === 'SCHEDULED') ||
      group.rounds[group.rounds.length - 1];

    const summary = await this.getGroupSummary(idirId, group.id);

    return {
      ...group,
      currentRound,
      summary,
    };
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
            payouts: {
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
        joinRequests: {
          where: { status: 'PENDING' },
          include: {
            membership: {
              include: {
                user: { select: { id: true, fullName: true, phoneNumber: true } },
              },
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

    return prisma.$transaction(async (tx) => {
      const maxCapacity = group.totalRounds * group.winnersPerRound;
      const currentCount = await tx.ikubParticipant.count({
        where: { ikubGroupId: groupId, status: 'ACTIVE' },
      });
      if (currentCount >= maxCapacity) {
        throw new BadRequestError(
          `This Ikub cycle has reached its maximum capacity of ${maxCapacity} participants (${group.totalRounds} rounds × ${group.winnersPerRound} winner(s)).`
        );
      }

      const participant = await tx.ikubParticipant.create({
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

      await tx.auditLog.create({
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
    });
  }

  async requestToJoin(
    idirId: string,
    groupId: string,
    membershipId: string,
    actorUserId: string,
    note?: string
  ) {
    const group = await prisma.ikubGroup.findFirst({
      where: { id: groupId, idirId, status: 'ACTIVE' },
    });
    if (!group) {
      throw new NotFoundError('Active Ikub group not found');
    }

    const membership = await prisma.membership.findFirst({
      where: { id: membershipId, idirId, status: 'ACTIVE' },
      include: {
        user: { select: { fullName: true, phoneNumber: true } },
      },
    });
    if (!membership) {
      throw new BadRequestError('Active Idir membership is required to join Ikub');
    }

    // Security Gate: Ensure caller owns the target membership
    if (membership.userId !== actorUserId) {
      throw new ForbiddenError('You can only enroll your own membership into the Ikub pool');
    }

    const existingParticipant = await prisma.ikubParticipant.findUnique({
      where: {
        ikubGroupId_membershipId: {
          ikubGroupId: groupId,
          membershipId,
        },
      },
    });
    if (existingParticipant) {
      throw new ConflictError('You are already an enrolled participant in this Ikub group');
    }

    // 1-Click Instant Enrollment: Directly register participant into active Ikub pool
    return prisma.$transaction(async (tx) => {
      // Capacity Constraint inside transaction: Prevent ROSCA insolvency / unbalanced participant counts
      const maxCapacity = group.totalRounds * group.winnersPerRound;
      const currentCount = await tx.ikubParticipant.count({
        where: { ikubGroupId: groupId, status: 'ACTIVE' },
      });
      if (currentCount >= maxCapacity) {
        throw new BadRequestError(
          `This Ikub cycle has reached its maximum capacity of ${maxCapacity} participants (${group.totalRounds} rounds × ${group.winnersPerRound} winner(s)).`
        );
      }

      const participant = await tx.ikubParticipant.create({
        data: {
          ikubGroupId: groupId,
          membershipId,
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

      // Record approved join request for audit and tracking
      await tx.ikubJoinRequest.upsert({
        where: {
          ikubGroupId_membershipId: {
            ikubGroupId: groupId,
            membershipId,
          },
        },
        create: {
          ikubGroupId: groupId,
          membershipId,
          note: note || '1-Click Instant Member Enrollment',
          status: 'APPROVED',
          reviewedAt: new Date(),
        },
        update: {
          note: note || '1-Click Instant Member Enrollment',
          status: 'APPROVED',
          reviewedAt: new Date(),
        },
      });

      await tx.auditLog.create({
        data: {
          actorId: actorUserId,
          idirId,
          action: 'JOIN_IKUB_INSTANT',
          entityType: 'IkubParticipant',
          entityId: participant.id,
          safeMetadata: { groupId, membershipId },
        },
      });

      return participant;
    });
  }

  async listJoinRequests(idirId: string, groupId: string) {
    const group = await prisma.ikubGroup.findFirst({
      where: { id: groupId, idirId },
    });
    if (!group) {
      throw new NotFoundError('Ikub group not found');
    }

    return prisma.ikubJoinRequest.findMany({
      where: { ikubGroupId: groupId, status: 'PENDING' },
      include: {
        membership: {
          include: {
            user: { select: { id: true, fullName: true, phoneNumber: true } },
          },
        },
      },
      orderBy: { requestedAt: 'asc' },
    });
  }

  async respondToJoinRequest(
    idirId: string,
    groupId: string,
    requestId: string,
    status: 'APPROVED' | 'REJECTED',
    actorId: string
  ) {
    const request = await prisma.ikubJoinRequest.findFirst({
      where: { id: requestId, ikubGroupId: groupId, ikubGroup: { idirId } },
    });
    if (!request) {
      throw new NotFoundError('Join request not found');
    }

    if (request.status !== 'PENDING') {
      throw new BadRequestError(`Join request has already been ${request.status.toLowerCase()}`);
    }

    return prisma.$transaction(async (tx) => {
      const updatedRequest = await tx.ikubJoinRequest.update({
        where: { id: requestId },
        data: {
          status,
          reviewedById: actorId,
          reviewedAt: new Date(),
        },
      });

      if (status === 'APPROVED') {
        const group = await tx.ikubGroup.findUnique({ where: { id: groupId } });
        if (!group) {
          throw new NotFoundError('Ikub group not found');
        }
        const maxCapacity = group.totalRounds * group.winnersPerRound;
        const currentCount = await tx.ikubParticipant.count({
          where: { ikubGroupId: groupId, status: 'ACTIVE' },
        });
        if (currentCount >= maxCapacity) {
          throw new BadRequestError(
            `Cannot approve join request: Ikub cycle is already at maximum capacity (${maxCapacity} participants)`
          );
        }

        const existingParticipant = await tx.ikubParticipant.findUnique({
          where: {
            ikubGroupId_membershipId: {
              ikubGroupId: groupId,
              membershipId: request.membershipId,
            },
          },
        });
        if (!existingParticipant) {
          await tx.ikubParticipant.create({
            data: {
              ikubGroupId: groupId,
              membershipId: request.membershipId,
              status: 'ACTIVE',
            },
          });
        }
      }

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: status === 'APPROVED' ? 'APPROVE_IKUB_JOIN' : 'REJECT_IKUB_JOIN',
          entityType: 'IkubJoinRequest',
          entityId: requestId,
          safeMetadata: { groupId, membershipId: request.membershipId, status },
        },
      });

      return updatedRequest;
    });
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

  async drawLottery(
    idirId: string,
    groupId: string,
    roundId: string,
    input: DrawLotteryInput,
    actorId: string
  ) {
    const group = await prisma.ikubGroup.findFirst({
      where: { id: groupId, idirId },
    });
    if (!group) {
      throw new NotFoundError('Ikub group not found');
    }

    return prisma.$transaction(async (tx) => {
      const round = await tx.ikubRound.findFirst({
        where: { id: roundId, ikubGroupId: groupId },
        include: { payouts: true },
      });
      if (!round) {
        throw new NotFoundError('Ikub round not found');
      }

      if (round.status === 'COMPLETED') {
        throw new BadRequestError('Round is already completed');
      }

      if (round.payouts.length >= group.winnersPerRound) {
        throw new ConflictError(
          `Round ${round.roundNumber} already has ${round.payouts.length} payout(s) recorded`
        );
      }

      // Check if a winner is already drawn and pending payout for this round
      const hasPendingWinner =
        Boolean(round.recipientParticipantId) &&
        !round.payouts.some((p) => p.recipientParticipantId === round.recipientParticipantId);

      if (hasPendingWinner && !input.isRedraw) {
        throw new ConflictError(
          `A winner has already been drawn for Round ${round.roundNumber} and is awaiting payout. Record their payout, or provide isRedraw: true with a valid redrawReason to conduct an audited redraw.`
        );
      }

      if (hasPendingWinner && input.isRedraw) {
        if (!input.redrawReason || input.redrawReason.trim().length < 5) {
          throw new BadRequestError(
            'A valid redrawReason (at least 5 characters) must be provided to conduct an audited redraw.'
          );
        }
      }

      // Collect participant IDs that already received payouts in this round
      const excludedParticipantIds = new Set<string>();
      for (const p of round.payouts) {
        excludedParticipantIds.add(p.recipientParticipantId);
      }
      // On redraw, also exclude the previous winner being replaced so we don't immediately redraw them
      if (hasPendingWinner && input.isRedraw && round.recipientParticipantId) {
        excludedParticipantIds.add(round.recipientParticipantId);
      }

      // Eligible participants: ACTIVE and hasWonPayout === false and not already drawn/paid in this round
      const eligibleParticipants = await tx.ikubParticipant.findMany({
        where: {
          ikubGroupId: groupId,
          status: 'ACTIVE',
          hasWonPayout: false,
          ...(excludedParticipantIds.size > 0
            ? { id: { notIn: Array.from(excludedParticipantIds) } }
            : {}),
        },
        include: {
          membership: {
            include: {
              user: { select: { id: true, fullName: true, phoneNumber: true } },
            },
          },
        },
      });

      if (eligibleParticipants.length === 0) {
        throw new BadRequestError(
          'No eligible participants remain who have not yet won an Ikub round'
        );
      }

      let winner = eligibleParticipants[0];
      let drawSeed = 'manual';

      if (input.manualWinnerId) {
        const match = eligibleParticipants.find((p) => p.id === input.manualWinnerId);
        if (!match) {
          throw new BadRequestError(
            'Selected manual winner is not eligible or has already won'
          );
        }
        winner = match;
      } else {
        const randomIndex = crypto.randomInt(0, eligibleParticipants.length);
        winner = eligibleParticipants[randomIndex];
        drawSeed = crypto.randomBytes(16).toString('hex');
      }

      // Update round with selected recipient and draw metadata
      const updatedRound = await tx.ikubRound.update({
        where: { id: roundId },
        data: {
          recipientParticipantId: winner.id,
          drawnById: actorId,
          drawnAt: new Date(),
          drawSeed,
          status: 'IN_PROGRESS',
        },
        include: {
          contributions: true,
          payouts: true,
        },
      });

      const auditAction =
        hasPendingWinner && input.isRedraw ? 'REDRAW_IKUB_LOTTERY' : 'DRAW_IKUB_LOTTERY';
      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: auditAction,
          entityType: 'IkubRound',
          entityId: round.id,
          safeMetadata: {
            groupId,
            roundNumber: round.roundNumber,
            winnerParticipantId: winner.id,
            winnerName: winner.membership.user.fullName,
            drawSeed,
            ...(hasPendingWinner && input.isRedraw
              ? {
                  previousWinnerParticipantId: round.recipientParticipantId,
                  redrawReason: input.redrawReason,
                }
              : {}),
          },
        },
      });

      return {
        winner: {
          id: winner.id,
          membershipId: winner.membershipId,
          fullName: winner.membership.user.fullName,
          phoneNumber: winner.membership.user.phoneNumber,
        },
        round: updatedRound,
        drawSeed,
      };
    });
  }

  async recordContribution(
    idirId: string,
    groupId: string,
    input: RecordIkubContributionInput,
    actorId: string
  ) {
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

    if (round.status === 'COMPLETED') {
      throw new BadRequestError('Cannot record contribution for an already completed round');
    }

    const participant = await prisma.ikubParticipant.findFirst({
      where: { id: input.participantId, ikubGroupId: groupId, status: 'ACTIVE' },
    });
    if (!participant) {
      throw new NotFoundError('Active participant not found in this Ikub group');
    }

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
    const group = await prisma.ikubGroup.findFirst({
      where: { id: groupId, idirId },
    });
    if (!group) {
      throw new NotFoundError('Ikub group not found');
    }

    return prisma.$transaction(async (tx) => {
      const round = await tx.ikubRound.findFirst({
        where: { id: input.roundId, ikubGroupId: groupId, ikubGroup: { idirId } },
        include: { payouts: true },
      });
      if (!round) {
        throw new NotFoundError('Ikub round not found');
      }

      if (round.status === 'COMPLETED') {
        throw new BadRequestError('Cannot record payout for an already completed round');
      }

      // 1. Validate draw has taken place
      if (!round.drawnAt || !round.recipientParticipantId) {
        throw new BadRequestError(
          'Cannot record payout: A lottery draw has not been conducted for this round yet'
        );
      }

      // 2. Validate recipient is the drawn winner for this round
      if (input.recipientParticipantId !== round.recipientParticipantId) {
        throw new BadRequestError(
          'Recipient participant is not the drawn winner for this round. Payouts can only be disbursed to the officially drawn winner.'
        );
      }

      if (round.payouts.length >= group.winnersPerRound) {
        throw new ConflictError(
          `Round ${round.roundNumber} has already reached the maximum of ${group.winnersPerRound} payout(s)`
        );
      }

      const existingPayout = round.payouts.find(
        (p) => p.recipientParticipantId === input.recipientParticipantId
      );
      if (existingPayout) {
        throw new ConflictError(
          `A payout has already been recorded for this recipient in Round ${round.roundNumber}`
        );
      }

      const participant = await tx.ikubParticipant.findFirst({
        where: { id: input.recipientParticipantId, ikubGroupId: groupId, status: 'ACTIVE' },
      });
      if (!participant) {
        throw new NotFoundError('Recipient participant not found in this Ikub group');
      }

      // 3. Enforce maximum payout bounds and split logic
      const activeCount = await tx.ikubParticipant.count({
        where: { ikubGroupId: groupId, status: 'ACTIVE' },
      });
      const maxPot = new Prisma.Decimal(group.contributionAmount).mul(activeCount);
      const maxWinnerShare = maxPot.div(group.winnersPerRound);

      if (new Prisma.Decimal(input.amount).gt(maxWinnerShare)) {
        throw new BadRequestError(
          `Payout amount cannot exceed the maximum allowed share of ${maxWinnerShare.toFixed(2)} ETB per winner (${group.winnersPerRound} winner(s) per round)`
        );
      }

      const totalPaidSoFar = round.payouts.reduce(
        (sum, p) => sum.add(p.amount),
        new Prisma.Decimal(0)
      );
      if (totalPaidSoFar.add(new Prisma.Decimal(input.amount)).gt(maxPot)) {
        throw new BadRequestError(
          `Total payouts for this round cannot exceed the total pool of ${maxPot.toFixed(2)} ETB`
        );
      }

      // Atomic Test-and-Set: CAS update on hasWonPayout: false -> true
      // This guarantees that concurrent requests cannot double-payout the same participant
      const updateParticipantRes = await tx.ikubParticipant.updateMany({
        where: {
          id: input.recipientParticipantId,
          ikubGroupId: groupId,
          status: 'ACTIVE',
          hasWonPayout: false,
        },
        data: { hasWonPayout: true },
      });
      if (updateParticipantRes.count === 0) {
        throw new ConflictError(
          'This participant has already won an Ikub payout in this cycle'
        );
      }

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

      // Check if total payouts for this round reaches winnersPerRound
      const totalPayoutsNow = round.payouts.length + 1;
      const isRoundFinished = totalPayoutsNow >= group.winnersPerRound;

      if (isRoundFinished) {
        await tx.ikubRound.update({
          where: { id: input.roundId },
          data: {
            status: 'COMPLETED',
            completedAt: new Date(),
            recipientParticipantId: input.recipientParticipantId,
          },
        });

        // If this was the last round, complete the IkubGroup
        if (round.roundNumber >= group.totalRounds) {
          await tx.ikubGroup.update({
            where: { id: groupId },
            data: { status: 'COMPLETED', endDate: new Date() },
          });
        } else {
          // Advance next round to IN_PROGRESS
          await tx.ikubRound.updateMany({
            where: {
              ikubGroupId: groupId,
              roundNumber: round.roundNumber + 1,
              status: 'SCHEDULED',
            },
            data: { status: 'IN_PROGRESS' },
          });
        }
      }

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
      winnersPerRound: group.winnersPerRound,
      financials: {
        totalCollected,
        totalPaidOut,
        remainingPool,
      },
    };
  }
}

export const ikubService = new IkubService();