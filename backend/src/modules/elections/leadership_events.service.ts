import { MembershipRole, NoConfidenceStatus, NoConfidenceChoice, Prisma } from '@prisma/client';
import { prisma } from '../../config/database.js';
import { AppError } from '../../shared/errors/AppError.js';
import type {
  InitiateNoConfidenceInput,
  CastNoConfidenceVoteInput,
  ResolveNoConfidenceInput,
  AppointInterimInput,
  CreateByElectionInput,
} from './leadership_events.validation.js';

export const INSTITUTIONAL_ROLES: MembershipRole[] = [
  MembershipRole.CHAIRPERSON,
  MembershipRole.TREASURER,
  MembershipRole.SECRETARY,
  MembershipRole.AUDITOR,
];

const ALLOWED_LEADERSHIP_MANAGERS: MembershipRole[] = [
  MembershipRole.CHAIRPERSON,
  MembershipRole.OFFICER,
  MembershipRole.COMMITTEE,
  MembershipRole.CREATOR,
];

export class LeadershipEventsService {
  /**
   * Initiate a formal vote of no-confidence against a sitting officer
   */
  async initiateNoConfidence(idirId: string, actorUserId: string, input: InitiateNoConfidenceInput) {
    const actorMembership = await prisma.membership.findFirst({
      where: { idirId, userId: actorUserId, status: 'ACTIVE' },
    });

    if (!actorMembership) {
      throw new AppError('Only active members of this Idir can initiate a no-confidence motion', 403, 'FORBIDDEN');
    }

    if (actorMembership.id === input.targetMembershipId) {
      throw new AppError('An officer cannot file a no-confidence motion against themselves', 400, 'BAD_REQUEST');
    }

    const targetMembership = await prisma.membership.findFirst({
      where: { idirId, id: input.targetMembershipId, status: 'ACTIVE' },
      include: { user: true },
    });

    if (!targetMembership) {
      throw new AppError('Target member not found or is not currently active in this Idir', 404, 'NOT_FOUND');
    }

    if (targetMembership.role !== input.targetRole || targetMembership.role === MembershipRole.MEMBER) {
      throw new AppError(
        `Target member does not currently hold the leadership role of ${input.targetRole}`,
        400,
        'BAD_REQUEST'
      );
    }

    // Check if an active no-confidence vote is already underway for this role
    const existingActiveVote = await prisma.noConfidenceVote.findFirst({
      where: {
        idirId,
        targetRole: input.targetRole,
        status: NoConfidenceStatus.ACTIVE,
      },
    });

    if (existingActiveVote) {
      throw new AppError(
        `A no-confidence vote is already active for the position of ${input.targetRole}`,
        400,
        'BAD_REQUEST'
      );
    }

    // Snapshot total eligible active members
    const totalEligibleMembers = await prisma.membership.count({
      where: { idirId, status: 'ACTIVE' },
    });

    const startDate = new Date();
    const endDate = new Date(startDate.getTime() + input.durationDays * 24 * 60 * 60 * 1000);

    return await prisma.$transaction(async (tx) => {
      const vote = await tx.noConfidenceVote.create({
        data: {
          idirId,
          targetMembershipId: input.targetMembershipId,
          targetRole: input.targetRole,
          initiatedByMembershipId: actorMembership.id,
          reason: input.reason,
          thresholdPercentage: new Prisma.Decimal(input.thresholdPercentage),
          quorumPercentage: new Prisma.Decimal(input.quorumPercentage),
          startDate,
          endDate,
          status: NoConfidenceStatus.ACTIVE,
          totalEligibleMembers,
          totalVotesCast: 0,
          supportVotes: 0,
          opposeVotes: 0,
        },
        include: {
          targetMembership: { include: { user: true } },
          initiatedByMembership: { include: { user: true } },
        },
      });

      await tx.auditLog.create({
        data: {
          idirId,
          actorId: actorUserId,
          action: 'INITIATE_NO_CONFIDENCE',
          entityType: 'NoConfidenceVote',
          entityId: vote.id,
          safeMetadata: {
            targetMembershipId: input.targetMembershipId,
            targetRole: input.targetRole,
            thresholdPercentage: input.thresholdPercentage,
            quorumPercentage: input.quorumPercentage,
            endDate: endDate.toISOString(),
          },
        },
      });

      return vote;
    });
  }

  /**
   * List all no-confidence votes in the Idir
   */
  async listNoConfidenceVotes(idirId: string, actorUserId: string) {
    const actorMembership = await prisma.membership.findFirst({
      where: { idirId, userId: actorUserId, status: 'ACTIVE' },
    });

    if (!actorMembership) {
      throw new AppError('Only active members of this Idir can view no-confidence votes', 403, 'FORBIDDEN');
    }

    const votes = await prisma.noConfidenceVote.findMany({
      where: { idirId },
      include: {
        targetMembership: {
          include: {
            user: {
              select: { id: true, fullName: true, phoneNumber: true },
            },
          },
        },
        initiatedByMembership: {
          include: {
            user: {
              select: { id: true, fullName: true, phoneNumber: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return votes;
  }

  /**
   * Get details of a single no-confidence vote including whether the actor has voted
   */
  async getNoConfidenceVote(idirId: string, voteId: string, actorUserId: string) {
    const actorMembership = await prisma.membership.findFirst({
      where: { idirId, userId: actorUserId, status: 'ACTIVE' },
    });

    if (!actorMembership) {
      throw new AppError('Only active members of this Idir can view no-confidence votes', 403, 'FORBIDDEN');
    }

    const vote = await prisma.noConfidenceVote.findFirst({
      where: { id: voteId, idirId },
      include: {
        targetMembership: {
          include: {
            user: {
              select: { id: true, fullName: true, phoneNumber: true },
            },
          },
        },
        initiatedByMembership: {
          include: {
            user: {
              select: { id: true, fullName: true, phoneNumber: true },
            },
          },
        },
      },
    });

    if (!vote) {
      throw new AppError('No-confidence vote not found', 404, 'NOT_FOUND');
    }

    const existingBallot = await prisma.noConfidenceBallot.findUnique({
      where: {
        voteId_voterMembershipId: {
          voteId,
          voterMembershipId: actorMembership.id,
        },
      },
    });

    return {
      ...vote,
      hasVoted: !!existingBallot,
    };
  }

  /**
   * Cast a vote on an active no-confidence motion
   */
  async castNoConfidenceVote(idirId: string, voteId: string, actorUserId: string, input: CastNoConfidenceVoteInput) {
    const actorMembership = await prisma.membership.findFirst({
      where: { idirId, userId: actorUserId, status: 'ACTIVE' },
    });

    if (!actorMembership) {
      throw new AppError('Only active members can vote in a no-confidence motion', 403, 'FORBIDDEN');
    }

    const vote = await prisma.noConfidenceVote.findFirst({
      where: { id: voteId, idirId },
    });

    if (!vote) {
      throw new AppError('No-confidence vote not found', 404, 'NOT_FOUND');
    }

    if (vote.status !== NoConfidenceStatus.ACTIVE) {
      throw new AppError('This no-confidence vote is no longer active', 400, 'BAD_REQUEST');
    }

    if (new Date() > new Date(vote.endDate)) {
      throw new AppError('The voting window for this no-confidence motion has expired', 400, 'BAD_REQUEST');
    }

    const existingBallot = await prisma.noConfidenceBallot.findUnique({
      where: {
        voteId_voterMembershipId: {
          voteId,
          voterMembershipId: actorMembership.id,
        },
      },
    });

    if (existingBallot) {
      throw new AppError('You have already cast your ballot in this no-confidence vote', 400, 'BAD_REQUEST');
    }

    const choiceEnum = input.choice === 'SUPPORT' ? NoConfidenceChoice.SUPPORT : NoConfidenceChoice.OPPOSE;

    return await prisma.$transaction(async (tx) => {
      await tx.noConfidenceBallot.create({
        data: {
          voteId,
          voterMembershipId: actorMembership.id,
          choice: choiceEnum,
        },
      });

      const updatedVote = await tx.noConfidenceVote.update({
        where: { id: voteId },
        data: {
          totalVotesCast: { increment: 1 },
          ...(input.choice === 'SUPPORT' ? { supportVotes: { increment: 1 } } : { opposeVotes: { increment: 1 } }),
        },
      });

      return {
        voteId: updatedVote.id,
        status: updatedVote.status,
        totalVotesCast: updatedVote.totalVotesCast,
        choiceRecorded: input.choice,
      };
    });
  }

  /**
   * Resolve and conclude a no-confidence vote
   * Checks quorum and threshold, removes the officer if passed, and vacates the role
   */
  async resolveNoConfidenceVote(idirId: string, voteId: string, actorUserId: string, input: ResolveNoConfidenceInput) {
    const actorMembership = await prisma.membership.findFirst({
      where: { idirId, userId: actorUserId, status: 'ACTIVE' },
    });

    if (!actorMembership) {
      throw new AppError('Only active members of this Idir can resolve a no-confidence vote', 403, 'FORBIDDEN');
    }

    const vote = await prisma.noConfidenceVote.findFirst({
      where: { id: voteId, idirId },
      include: { targetMembership: true },
    });

    if (!vote) {
      throw new AppError('No-confidence vote not found', 404, 'NOT_FOUND');
    }

    if (vote.status !== NoConfidenceStatus.ACTIVE) {
      throw new AppError(`Cannot resolve vote: already ${vote.status}`, 400, 'BAD_REQUEST');
    }

    const now = new Date();
    if (!input.force && now < new Date(vote.endDate)) {
      throw new AppError(
        'Voting window is still open. Cannot conclude vote before end date without force parameter',
        400,
        'BAD_REQUEST'
      );
    }

    const totalEligible = vote.totalEligibleMembers > 0 ? vote.totalEligibleMembers : 1;
    const turnoutPercentage = (vote.totalVotesCast / totalEligible) * 100;
    const quorumRequired = Number(vote.quorumPercentage);
    const thresholdRequired = Number(vote.thresholdPercentage);

    const quorumReached = turnoutPercentage >= quorumRequired;
    const supportPercentage = vote.totalVotesCast > 0 ? (vote.supportVotes / vote.totalVotesCast) * 100 : 0;
    const passed = quorumReached && supportPercentage >= thresholdRequired;

    let finalStatus: NoConfidenceStatus;
    if (!quorumReached) {
      finalStatus = NoConfidenceStatus.FAILED_NO_QUORUM;
    } else if (passed) {
      finalStatus = NoConfidenceStatus.PASSED;
    } else {
      finalStatus = NoConfidenceStatus.FAILED;
    }

    return await prisma.$transaction(async (tx) => {
      let roleVacated = false;

      if (finalStatus === NoConfidenceStatus.PASSED) {
        // Demote target officer back to regular MEMBER
        await tx.membership.update({
          where: { id: vote.targetMembershipId },
          data: { role: MembershipRole.MEMBER },
        });

        // Terminate any active RoleTerm for this target
        await tx.roleTerm.updateMany({
          where: {
            idirId,
            membershipId: vote.targetMembershipId,
            role: vote.targetRole,
            status: 'ACTIVE',
          },
          data: {
            status: 'TERMINATED_NO_CONFIDENCE',
            endDate: now,
          },
        });

        roleVacated = true;
      }

      const updatedVote = await tx.noConfidenceVote.update({
        where: { id: voteId },
        data: {
          status: finalStatus,
          resolvedAt: now,
        },
        include: {
          targetMembership: { include: { user: true } },
          initiatedByMembership: { include: { user: true } },
        },
      });

      await tx.auditLog.create({
        data: {
          idirId,
          actorId: actorUserId,
          action: finalStatus === NoConfidenceStatus.PASSED ? 'NO_CONFIDENCE_PASSED' : 'NO_CONFIDENCE_FAILED',
          entityType: 'NoConfidenceVote',
          entityId: vote.id,
          safeMetadata: {
            finalStatus,
            targetMembershipId: vote.targetMembershipId,
            targetRole: vote.targetRole,
            totalVotesCast: vote.totalVotesCast,
            supportVotes: vote.supportVotes,
            supportPercentage: Math.round(supportPercentage * 100) / 100,
            turnoutPercentage: Math.round(turnoutPercentage * 100) / 100,
            quorumReached,
            roleVacated,
          },
        },
      });

      return {
        vote: updatedVote,
        result: {
          finalStatus,
          passed: finalStatus === NoConfidenceStatus.PASSED,
          turnoutPercentage: Math.round(turnoutPercentage * 100) / 100,
          quorumRequired,
          quorumReached,
          supportPercentage: Math.round(supportPercentage * 100) / 100,
          thresholdRequired,
          roleVacated,
          vacatedRole: vote.targetRole,
        },
      };
    });
  }

  /**
   * Inspect all institutional leadership roles and determine vacancies
   */
  async getLeadershipVacancies(idirId: string, actorUserId: string) {
    const actorMembership = await prisma.membership.findFirst({
      where: { idirId, userId: actorUserId, status: 'ACTIVE' },
    });

    if (!actorMembership) {
      throw new AppError('Only active members of this Idir can view leadership vacancies', 403, 'FORBIDDEN');
    }

    const vacancies = [];

    for (const role of INSTITUTIONAL_ROLES) {
      // Find current active member holding this role
      const currentHolder = await prisma.membership.findFirst({
        where: { idirId, role, status: 'ACTIVE' },
        include: {
          user: {
            select: { id: true, fullName: true, phoneNumber: true },
          },
        },
      });

      // Find latest role term
      const latestTerm = currentHolder
        ? await prisma.roleTerm.findFirst({
            where: { idirId, membershipId: currentHolder.id, role },
            orderBy: { createdAt: 'desc' },
          })
        : null;

      // Check active no-confidence vote for this role
      const activeNoConfidence = await prisma.noConfidenceVote.findFirst({
        where: { idirId, targetRole: role, status: NoConfidenceStatus.ACTIVE },
        select: { id: true, endDate: true },
      });

      let status: 'OCCUPIED' | 'VACANT' | 'INTERIM';
      if (!currentHolder) {
        status = 'VACANT';
      } else if (latestTerm?.status === 'INTERIM') {
        status = 'INTERIM';
      } else {
        status = 'OCCUPIED';
      }

      vacancies.push({
        role,
        status,
        currentHolder: currentHolder
          ? {
              membershipId: currentHolder.id,
              userId: currentHolder.userId,
              fullName: currentHolder.user.fullName,
              phoneNumber: currentHolder.user.phoneNumber,
              memberNumber: currentHolder.memberNumber,
            }
          : null,
        term: latestTerm
          ? {
              startDate: latestTerm.startDate,
              endDate: latestTerm.endDate,
              status: latestTerm.status,
            }
          : null,
        activeNoConfidenceVoteId: activeNoConfidence?.id ?? null,
      });
    }

    return vacancies;
  }

  /**
   * Appoint an active member to temporarily fill a vacant leadership seat
   */
  async appointTemporaryOfficer(idirId: string, actorUserId: string, input: AppointInterimInput) {
    const actorMembership = await prisma.membership.findFirst({
      where: { idirId, userId: actorUserId, status: 'ACTIVE' },
    });

    if (!actorMembership || !ALLOWED_LEADERSHIP_MANAGERS.includes(actorMembership.role)) {
      throw new AppError('Only authorized officers or committee members can make interim appointments', 403, 'FORBIDDEN');
    }

    const appointee = await prisma.membership.findFirst({
      where: { idirId, id: input.appointeeMembershipId, status: 'ACTIVE' },
      include: { user: true },
    });

    if (!appointee) {
      throw new AppError('Appointee must be an active member of this Idir', 404, 'NOT_FOUND');
    }

    const now = new Date();
    const interimEndDate = new Date(now.getTime() + input.termMonths * 30 * 24 * 60 * 60 * 1000);

    return await prisma.$transaction(async (tx) => {
      // Demote any existing occupant of the role to regular MEMBER
      await tx.membership.updateMany({
        where: { idirId, role: input.vacantRole, status: 'ACTIVE' },
        data: { role: MembershipRole.MEMBER },
      });

      // Promote appointee to the vacant role
      const updatedAppointee = await tx.membership.update({
        where: { id: input.appointeeMembershipId },
        data: { role: input.vacantRole },
        include: { user: true },
      });

      // Create new interim RoleTerm
      const newTerm = await tx.roleTerm.create({
        data: {
          idirId,
          membershipId: input.appointeeMembershipId,
          role: input.vacantRole,
          startDate: now,
          endDate: interimEndDate,
          status: 'INTERIM',
        },
      });

      await tx.auditLog.create({
        data: {
          idirId,
          actorId: actorUserId,
          action: 'TEMPORARY_APPOINTMENT',
          entityType: 'Membership',
          entityId: input.appointeeMembershipId,
          safeMetadata: {
            vacantRole: input.vacantRole,
            appointeeName: appointee.user.fullName,
            reason: input.reason ?? 'Emergency interim leadership coverage',
            termMonths: input.termMonths,
            endDate: interimEndDate.toISOString(),
          },
        },
      });

      return {
        appointee: {
          membershipId: updatedAppointee.id,
          role: updatedAppointee.role,
          fullName: updatedAppointee.user.fullName,
        },
        term: newTerm,
      };
    });
  }

  /**
   * Schedule an expedited by-election for a vacant leadership seat
   */
  async createByElection(idirId: string, actorUserId: string, input: CreateByElectionInput) {
    const actorMembership = await prisma.membership.findFirst({
      where: { idirId, userId: actorUserId, status: 'ACTIVE' },
    });

    if (!actorMembership || !ALLOWED_LEADERSHIP_MANAGERS.includes(actorMembership.role)) {
      throw new AppError('Only authorized officers or committee members can schedule by-elections', 403, 'FORBIDDEN');
    }

    // Verify all committee members are active members of this Idir
    const activeCommitteeMembers = await prisma.membership.findMany({
      where: {
        idirId,
        id: { in: input.committeeMemberIds },
        status: 'ACTIVE',
      },
    });

    if (activeCommitteeMembers.length !== input.committeeMemberIds.length) {
      throw new AppError(
        'All committee members for the by-election must be active members of this Idir',
        400,
        'BAD_REQUEST'
      );
    }

    const title = input.title ?? `By-Election for ${input.vacantRole}`;
    const description =
      input.description ?? `Expedited special election to fill the vacant ${input.vacantRole} leadership seat.`;

    return await prisma.$transaction(async (tx) => {
      const election = await tx.election.create({
        data: {
          idirId,
          title,
          description,
          roles: [input.vacantRole],
          startDate: new Date(input.startDate),
          endDate: new Date(input.endDate),
          nominationStartDate: input.nominationStartDate ? new Date(input.nominationStartDate) : null,
          nominationEndDate: input.nominationEndDate ? new Date(input.nominationEndDate) : null,
          termLengthMonths: input.termLengthMonths,
          votingMethod: input.votingMethod,
          ballotType: input.ballotType,
          quorumPercentage: new Prisma.Decimal(input.quorumPercentage),
          status: 'DRAFT',
          createdById: actorUserId,
          committeeMembers: {
            create: input.committeeMemberIds.map((memberId) => ({
              membershipId: memberId,
              role: 'BY_ELECTION_COMMITTEE',
            })),
          },
        },
        include: {
          committeeMembers: true,
        },
      });

      await tx.auditLog.create({
        data: {
          idirId,
          actorId: actorUserId,
          action: 'CREATE_BY_ELECTION',
          entityType: 'Election',
          entityId: election.id,
          safeMetadata: {
            vacantRole: input.vacantRole,
            title,
            committeeMemberIds: input.committeeMemberIds,
          },
        },
      });

      return election;
    });
  }
}

export const leadershipEventsService = new LeadershipEventsService();
