import { MembershipRole, ElectionStatus, DisputeStatus } from '@prisma/client';
import { prisma } from '../../config/database.js';
import {
  BadRequestError,
  ForbiddenError,
  NotFoundError,
} from '../../shared/errors/AppError.js';
import { assertIdirActive } from '../../middleware/assertIdirActive.js';
import { ALLOWED_ELECTION_OFFICER_ROLES } from './elections.service.js';
import { TallyVotesInput, FileDisputeInput, ResolveDisputeInput, TriggerRunoffInput } from './results.validation.js';

export interface CandidateTallyItem {
  nominationId: string;
  nomineeMembershipId: string;
  nomineeName: string;
  statement?: string | null;
  votes: number;
  percentage: number;
}

export interface RoleResultItem {
  role: MembershipRole;
  winnerNominationId: string | null;
  winnerName: string | null;
  winnerMembershipId: string | null;
  totalVotesCast: number;
  votesReceived: number;
  isTie: boolean;
  tiedCandidateIds?: string[];
  candidates: CandidateTallyItem[];
}

export class ResultsService {
  /**
   * Helper to verify if the caller is an active election officer or neutral committee member.
   */
  private async getOfficerOrCommitteeMembership(idirId: string, electionId: string, actorUserId: string) {
    const membership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId: actorUserId,
        },
      },
      include: {
        electionCommitteeMemberships: {
          where: { electionId },
        },
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('Active Idir membership is required to perform election operations');
    }

    const isOfficer = ALLOWED_ELECTION_OFFICER_ROLES.includes(membership.role);
    const isCommitteeMember = membership.electionCommitteeMemberships.length > 0;

    if (!isOfficer && !isCommitteeMember) {
      throw new ForbiddenError(
        'Only election committee members or authorized officers (Chairperson, Creator, Secretary) can perform this action'
      );
    }

    return { membership, isOfficer, isCommitteeMember };
  }

  /**
   * Tally votes for an election:
   * 1. Validates voting window & authorization.
   * 2. Checks Quorum: (unique voters / total active members) >= quorumPercentage.
   *    If below quorum, election is declared invalid and results marked quorumReached = false.
   * 3. Counts votes per role, identifies winner or detects ties for run-offs.
   * 4. Publishes preliminary results and opens the dispute window (e.g., 48 hours).
   */
  async tallyVotes(idirId: string, electionId: string, actorUserId: string, input?: TallyVotesInput) {
    await assertIdirActive(idirId);
    await this.getOfficerOrCommitteeMembership(idirId, electionId, actorUserId);

    const election = await prisma.election.findFirst({
      where: { id: electionId, idirId },
      include: {
        nominations: {
          include: {
            nomineeMembership: {
              include: { user: { select: { fullName: true } } },
            },
          },
        },
        committeeMembers: true,
      },
    });

    if (!election) {
      throw new NotFoundError('Election not found');
    }

    if (election.status === 'COMPLETED') {
      throw new BadRequestError('Election has already been completed and certified');
    }

    if (election.status === 'CANCELLED') {
      throw new BadRequestError('Cannot tally a cancelled election');
    }

    if (election.status === 'DRAFT' || election.status === 'NOMINATING') {
      throw new BadRequestError('Cannot tally votes before the voting period has commenced');
    }

    const now = new Date();
    const isVotingEnded = now >= election.endDate;
    if (!isVotingEnded && !input?.force) {
      throw new BadRequestError(
        `Voting window is currently open until ${election.endDate.toISOString()}. Automatic tallying occurs when voting concludes.`
      );
    }

    // ── 1. Calculate Quorum ──────────────────────────────────────────────────
    const totalEligibleMembers = await prisma.membership.count({
      where: {
        idirId,
        status: 'ACTIVE',
      },
    });

    const uniqueVoters = await prisma.voteReceipt.groupBy({
      by: ['membershipId'],
      where: { electionId },
    });
    const uniqueVotersCount = uniqueVoters.length;

    const turnoutPercentage =
      totalEligibleMembers > 0
        ? Number(((uniqueVotersCount / totalEligibleMembers) * 100).toFixed(2))
        : 0;

    const quorumPercentage = Number(election.quorumPercentage);
    const quorumReached = turnoutPercentage >= quorumPercentage;

    const disputeWindowEndsAt = new Date(
      now.getTime() + election.disputeWindowHours * 60 * 60 * 1000
    );

    // ── 2. Handle Quorum Failure ─────────────────────────────────────────────
    if (!quorumReached) {
      return await prisma.$transaction(async (tx) => {
        // Record quorum failure on all roles
        for (const role of election.roles) {
          const roleBallotsCount = await tx.ballot.count({
            where: { electionId, role },
          });

          await tx.electionResult.upsert({
            where: {
              electionId_role: { electionId, role },
            },
            update: {
              winnerNominationId: null,
              totalVotesCast: roleBallotsCount,
              votesReceived: 0,
              quorumReached: false,
              isFinal: true,
              disputeWindowEndsAt: null,
            },
            create: {
              electionId,
              role,
              winnerNominationId: null,
              totalVotesCast: roleBallotsCount,
              votesReceived: 0,
              quorumReached: false,
              isFinal: true,
              disputeWindowEndsAt: null,
            },
          });
        }

        // Mark election cancelled/failed due to quorum
        await tx.election.update({
          where: { id: electionId },
          data: { status: 'CANCELLED' },
        });

        await tx.auditLog.create({
          data: {
            actorId: actorUserId,
            idirId,
            action: 'ELECTION_QUORUM_FAILED',
            entityType: 'Election',
            entityId: electionId,
            safeMetadata: {
              turnoutPercentage,
              quorumPercentage,
              uniqueVotersCount,
              totalEligibleMembers,
              reason: `Turnout of ${turnoutPercentage}% was below the required quorum of ${quorumPercentage}%`,
            },
          },
        });

        return {
          isValid: false,
          quorumReached: false,
          status: 'CANCELLED',
          turnoutPercentage,
          quorumPercentage,
          uniqueVotersCount,
          totalEligibleMembers,
          message: `Election invalid: Voter turnout (${turnoutPercentage}%) did not reach the required quorum of ${quorumPercentage}%.`,
          roles: [],
        };
      });
    }

    // ── 3. Quorum Reached: Tally Votes Per Role ──────────────────────────────
    return await prisma.$transaction(async (tx) => {
      const roleResults: RoleResultItem[] = [];
      let anyTieDetected = false;

      for (const role of election.roles) {
        const ballots = await tx.ballot.findMany({
          where: { electionId, role },
          select: { candidateNominationId: true },
        });

        const voteCountMap = new Map<string, number>();
        for (const b of ballots) {
          if (b.candidateNominationId) {
            voteCountMap.set(
              b.candidateNominationId,
              (voteCountMap.get(b.candidateNominationId) || 0) + 1
            );
          }
        }

        const acceptedNominations = election.nominations.filter(
          (n) => n.role === role && n.status === 'ACCEPTED'
        );

        const totalVotesCast = ballots.length;

        const candidateTallies: CandidateTallyItem[] = acceptedNominations.map((nom) => {
          const votes = voteCountMap.get(nom.id) || 0;
          const percentage = totalVotesCast > 0 ? Number(((votes / totalVotesCast) * 100).toFixed(1)) : 0;
          return {
            nominationId: nom.id,
            nomineeMembershipId: nom.nomineeMembershipId,
            nomineeName: nom.nomineeMembership.user.fullName,
            statement: nom.statement,
            votes,
            percentage,
          };
        });

        // Sort descending by vote count
        candidateTallies.sort((a, b) => b.votes - a.votes);

        let winnerNominationId: string | null = null;
        let winnerName: string | null = null;
        let winnerMembershipId: string | null = null;
        let votesReceived = 0;
        let isTie = false;
        let tiedCandidateIds: string[] = [];

        if (candidateTallies.length > 0) {
          const topCandidate = candidateTallies[0];
          const maxVotes = topCandidate.votes;
          const tied = candidateTallies.filter((c) => c.votes === maxVotes && maxVotes > 0);

          if (tied.length > 1) {
            isTie = true;
            anyTieDetected = true;
            tiedCandidateIds = tied.map((c) => c.nominationId);
            winnerNominationId = null; // No winner yet, run-off or tie-breaker needed!
            votesReceived = maxVotes;
          } else if (maxVotes > 0) {
            winnerNominationId = topCandidate.nominationId;
            winnerName = topCandidate.nomineeName;
            winnerMembershipId = topCandidate.nomineeMembershipId;
            votesReceived = topCandidate.votes;
          }
        }

        await tx.electionResult.upsert({
          where: {
            electionId_role: { electionId, role },
          },
          update: {
            winnerNominationId,
            totalVotesCast,
            votesReceived,
            quorumReached: true,
            isFinal: false,
            disputeWindowEndsAt,
          },
          create: {
            electionId,
            role,
            winnerNominationId,
            totalVotesCast,
            votesReceived,
            quorumReached: true,
            isFinal: false,
            disputeWindowEndsAt,
          },
        });

        roleResults.push({
          role,
          winnerNominationId,
          winnerName,
          winnerMembershipId,
          totalVotesCast,
          votesReceived,
          isTie,
          tiedCandidateIds: isTie ? tiedCandidateIds : undefined,
          candidates: candidateTallies,
        });
      }

      // Transition election status to TALLYING while results are published in dispute window
      await tx.election.update({
        where: { id: electionId },
        data: { status: 'TALLYING' },
      });

      await tx.auditLog.create({
        data: {
          actorId: actorUserId,
          idirId,
          action: 'TALLY_ELECTION_VOTES',
          entityType: 'Election',
          entityId: electionId,
          safeMetadata: {
            turnoutPercentage,
            quorumPercentage,
            uniqueVotersCount,
            totalEligibleMembers,
            quorumReached: true,
            anyTieDetected,
            disputeWindowEndsAt: disputeWindowEndsAt.toISOString(),
          },
        },
      });

      return {
        isValid: true,
        quorumReached: true,
        status: 'TALLYING',
        turnoutPercentage,
        quorumPercentage,
        uniqueVotersCount,
        totalEligibleMembers,
        disputeWindowEndsAt: disputeWindowEndsAt.toISOString(),
        disputeWindowHours: election.disputeWindowHours,
        anyTieDetected,
        roles: roleResults,
        message: anyTieDetected
          ? 'Votes tallied. Ties detected for one or more contested roles; run-off or tie-breaker required.'
          : 'Votes tallied and preliminary results published. Dispute window is now active.',
      };
    });
  }

  /**
   * Get election results, turnout metrics, and dispute window status.
   */
  async getResults(idirId: string, electionId: string) {
    await assertIdirActive(idirId);

    const election = await prisma.election.findFirst({
      where: { id: electionId, idirId },
      include: {
        results: {
          include: {
            winnerNomination: {
              include: {
                nomineeMembership: {
                  include: { user: { select: { fullName: true } } },
                },
              },
            },
          },
        },
        nominations: {
          where: { status: 'ACCEPTED' },
          include: {
            nomineeMembership: {
              include: { user: { select: { fullName: true } } },
            },
          },
        },
        disputes: true,
      },
    });

    if (!election) {
      throw new NotFoundError('Election not found');
    }

    const totalEligibleMembers = await prisma.membership.count({
      where: { idirId, status: 'ACTIVE' },
    });

    const uniqueVoters = await prisma.voteReceipt.groupBy({
      by: ['membershipId'],
      where: { electionId },
    });
    const uniqueVotersCount = uniqueVoters.length;

    const turnoutPercentage =
      totalEligibleMembers > 0
        ? Number(((uniqueVotersCount / totalEligibleMembers) * 100).toFixed(2))
        : 0;

    const quorumPercentage = Number(election.quorumPercentage);
    const quorumReached = turnoutPercentage >= quorumPercentage;

    const now = new Date();
    const disputeWindowEndsAt = election.results[0]?.disputeWindowEndsAt ?? null;
    const isDisputeWindowOpen =
      disputeWindowEndsAt !== null && now <= disputeWindowEndsAt && election.status !== 'COMPLETED';

    const hoursRemaining =
      disputeWindowEndsAt && now < disputeWindowEndsAt
        ? Number(((disputeWindowEndsAt.getTime() - now.getTime()) / (1000 * 60 * 60)).toFixed(1))
        : 0;

    const roleResults: RoleResultItem[] = [];

    for (const role of election.roles) {
      const storedResult = election.results.find((r) => r.role === role);
      const roleNominations = election.nominations.filter((n) => n.role === role);

      const ballots = await prisma.ballot.findMany({
        where: { electionId, role },
        select: { candidateNominationId: true },
      });

      const voteCountMap = new Map<string, number>();
      for (const b of ballots) {
        if (b.candidateNominationId) {
          voteCountMap.set(
            b.candidateNominationId,
            (voteCountMap.get(b.candidateNominationId) || 0) + 1
          );
        }
      }

      const totalVotesCast = ballots.length;

      const candidates: CandidateTallyItem[] = roleNominations.map((nom) => {
        const votes = voteCountMap.get(nom.id) || 0;
        const percentage = totalVotesCast > 0 ? Number(((votes / totalVotesCast) * 100).toFixed(1)) : 0;
        return {
          nominationId: nom.id,
          nomineeMembershipId: nom.nomineeMembershipId,
          nomineeName: nom.nomineeMembership.user.fullName,
          statement: nom.statement,
          votes,
          percentage,
        };
      });

      candidates.sort((a, b) => b.votes - a.votes);

      const maxVotes = candidates[0]?.votes ?? 0;
      const tied = candidates.filter((c) => c.votes === maxVotes && maxVotes > 0);
      const isTie = tied.length > 1;

      roleResults.push({
        role,
        winnerNominationId: storedResult?.winnerNominationId ?? (isTie ? null : candidates[0]?.nominationId ?? null),
        winnerName: storedResult?.winnerNomination?.nomineeMembership.user.fullName ?? (isTie ? null : candidates[0]?.nomineeName ?? null),
        winnerMembershipId: storedResult?.winnerNomination?.nomineeMembershipId ?? (isTie ? null : candidates[0]?.nomineeMembershipId ?? null),
        totalVotesCast,
        votesReceived: storedResult?.votesReceived ?? (candidates[0]?.votes ?? 0),
        isTie,
        tiedCandidateIds: isTie ? tied.map((c) => c.nominationId) : undefined,
        candidates,
      });
    }

    const pendingDisputesCount = election.disputes.filter((d) => d.status === 'PENDING').length;
    const isCertified = election.status === 'COMPLETED';

    return {
      electionId,
      electionTitle: election.title,
      status: election.status,
      votingMethod: election.votingMethod,
      ballotType: election.ballotType,
      termLengthMonths: election.termLengthMonths,
      handoverDate: election.handoverDate?.toISOString() ?? null,
      totalEligibleMembers,
      uniqueVotersCount,
      turnoutPercentage,
      quorumPercentage,
      quorumReached,
      disputeWindowEndsAt: disputeWindowEndsAt?.toISOString() ?? null,
      isDisputeWindowOpen,
      hoursRemaining,
      pendingDisputesCount,
      isCertified,
      roles: roleResults,
    };
  }

  /**
   * File an election dispute during the active dispute window.
   */
  async fileDispute(idirId: string, electionId: string, actorUserId: string, input: FileDisputeInput) {
    await assertIdirActive(idirId);

    const membership = await prisma.membership.findUnique({
      where: {
        idirId_userId: { idirId, userId: actorUserId },
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('Only active members of this Idir can file an election dispute');
    }

    const election = await prisma.election.findFirst({
      where: { id: electionId, idirId },
      include: { results: true },
    });

    if (!election) {
      throw new NotFoundError('Election not found');
    }

    if (election.status === 'COMPLETED') {
      throw new BadRequestError('Cannot file a dispute for an election that has already been certified');
    }

    if (election.results.length === 0) {
      throw new BadRequestError('Cannot file a dispute before preliminary election results are published');
    }

    const disputeWindowEndsAt = election.results[0].disputeWindowEndsAt;
    const now = new Date();
    if (!disputeWindowEndsAt || now > disputeWindowEndsAt) {
      throw new BadRequestError('The dispute window for this election has closed');
    }

    return await prisma.$transaction(async (tx) => {
      const dispute = await tx.electionDispute.create({
        data: {
          electionId,
          filedByMembershipId: membership.id,
          reason: input.reason,
          status: 'PENDING',
        },
      });

      // Update election status to DISPUTED
      await tx.election.update({
        where: { id: electionId },
        data: { status: 'DISPUTED' },
      });

      await tx.auditLog.create({
        data: {
          actorId: actorUserId,
          idirId,
          action: 'FILE_ELECTION_DISPUTE',
          entityType: 'ElectionDispute',
          entityId: dispute.id,
          safeMetadata: {
            electionId,
            filedByMembershipId: membership.id,
            reason: input.reason,
          },
        },
      });

      return dispute;
    });
  }

  /**
   * List all disputes filed for an election.
   */
  async listDisputes(idirId: string, electionId: string) {
    await assertIdirActive(idirId);

    return await prisma.electionDispute.findMany({
      where: { electionId, election: { idirId } },
      include: {
        filedByMembership: {
          include: {
            user: { select: { fullName: true, phoneNumber: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Review and resolve or dismiss an election dispute.
   * Restricted to Election Committee members or Chairperson.
   */
  async resolveDispute(
    idirId: string,
    electionId: string,
    disputeId: string,
    actorUserId: string,
    input: ResolveDisputeInput
  ) {
    await assertIdirActive(idirId);
    await this.getOfficerOrCommitteeMembership(idirId, electionId, actorUserId);

    const dispute = await prisma.electionDispute.findFirst({
      where: { id: disputeId, electionId, election: { idirId } },
    });

    if (!dispute) {
      throw new NotFoundError('Dispute not found for this election');
    }

    if (dispute.status !== 'PENDING') {
      throw new BadRequestError(`Dispute has already been ${dispute.status.toLowerCase()}`);
    }

    const resolvedStatus: DisputeStatus = input.action === 'RESOLVE' ? 'RESOLVED' : 'DISMISSED';

    return await prisma.$transaction(async (tx) => {
      const updatedDispute = await tx.electionDispute.update({
        where: { id: disputeId },
        data: {
          status: resolvedStatus,
          resolution: input.resolution,
          resolvedAt: new Date(),
          resolvedById: actorUserId,
        },
      });

      // Check if any other disputes remain PENDING
      const remainingPending = await tx.electionDispute.count({
        where: { electionId, status: 'PENDING' },
      });

      if (remainingPending === 0) {
        // Return election status to TALLYING
        await tx.election.update({
          where: { id: electionId },
          data: { status: 'TALLYING' },
        });
      }

      await tx.auditLog.create({
        data: {
          actorId: actorUserId,
          idirId,
          action: 'RESOLVE_ELECTION_DISPUTE',
          entityType: 'ElectionDispute',
          entityId: disputeId,
          safeMetadata: {
            action: input.action,
            resolution: input.resolution,
            remainingPendingDisputes: remainingPending,
          },
        },
      });

      return updatedDispute;
    });
  }

  /**
   * Certify election results and transfer leadership roles:
   * Done when:
   * 1. Preliminary results exist and quorum was reached.
   * 2. No unresolved ties (each contested role has a clear winner).
   * 3. Dispute window has expired OR all pending disputes are resolved.
   * 4. Leadership roles ONLY transfer upon certification!
   */
  async certifyElection(idirId: string, electionId: string, actorUserId: string) {
    await assertIdirActive(idirId);
    await this.getOfficerOrCommitteeMembership(idirId, electionId, actorUserId);

    const election = await prisma.election.findFirst({
      where: { id: electionId, idirId },
      include: {
        results: {
          include: {
            winnerNomination: true,
          },
        },
        disputes: {
          where: { status: 'PENDING' },
        },
      },
    });

    if (!election) {
      throw new NotFoundError('Election not found');
    }

    if (election.status === 'COMPLETED') {
      throw new BadRequestError('Election is already certified and leadership roles transferred');
    }

    if (election.results.length === 0) {
      throw new BadRequestError('Cannot certify an election before votes have been tallied');
    }

    // 1. Quorum check
    const quorumFailed = election.results.some((r) => !r.quorumReached);
    if (quorumFailed) {
      throw new BadRequestError('Cannot certify election: voter turnout failed to meet required quorum');
    }

    // 2. Unresolved ties check
    const tiedRoles = election.results.filter((r) => !r.winnerNominationId);
    if (tiedRoles.length > 0) {
      const rolesList = tiedRoles.map((r) => r.role).join(', ');
      throw new BadRequestError(
        `Cannot certify election: Unresolved ties exist for role(s): ${rolesList}. Run-off or tie-breaker must be completed first.`
      );
    }

    // 3. Pending disputes check
    if (election.disputes.length > 0) {
      throw new BadRequestError(
        `Cannot certify election: There are ${election.disputes.length} pending dispute(s) that must be resolved first.`
      );
    }

    const now = new Date();

    // ── 4. Atomic Certification & Leadership Role Transfer ───────────────────
    return await prisma.$transaction(async (tx) => {
      const transferredRoles: Array<{ role: MembershipRole; newLeaderMembershipId: string }> = [];

      for (const result of election.results) {
        if (!result.winnerNomination) continue;

        const role = result.role;
        const newLeaderMembershipId = result.winnerNomination.nomineeMembershipId;

        // A. Expire any existing active RoleTerm for this role in this Idir
        await tx.roleTerm.updateMany({
          where: {
            idirId,
            role,
            status: 'ACTIVE',
          },
          data: {
            status: 'EXPIRED',
            endDate: now,
          },
        });

        // B. Reassign previous role holder(s) in this Idir back to regular MEMBER
        await tx.membership.updateMany({
          where: {
            idirId,
            role,
            id: { not: newLeaderMembershipId },
          },
          data: {
            role: 'MEMBER',
          },
        });

        // C. Promote winning candidate's Membership to the new leadership role
        await tx.membership.update({
          where: { id: newLeaderMembershipId },
          data: { role },
        });

        // D. Create new RoleTerm record
        const termStart = election.handoverDate && election.handoverDate > now ? election.handoverDate : now;
        const termEnd = new Date(termStart.getTime() + election.termLengthMonths * 30 * 24 * 60 * 60 * 1000);

        await tx.roleTerm.create({
          data: {
            idirId,
            membershipId: newLeaderMembershipId,
            role,
            startDate: termStart,
            endDate: termEnd,
            electionId,
            status: 'ACTIVE',
          },
        });

        transferredRoles.push({ role, newLeaderMembershipId });
      }

      // Mark all ElectionResults as isFinal = true
      await tx.electionResult.updateMany({
        where: { electionId },
        data: { isFinal: true },
      });

      // Transition election to COMPLETED
      await tx.election.update({
        where: { id: electionId },
        data: { status: 'COMPLETED' },
      });

      // Audit Log for official certification and leadership handover
      await tx.auditLog.create({
        data: {
          actorId: actorUserId,
          idirId,
          action: 'CERTIFY_ELECTION_AND_TRANSFER_ROLES',
          entityType: 'Election',
          entityId: electionId,
          safeMetadata: {
            electionId,
            transferredRoles,
            certifiedAt: now.toISOString(),
          },
        },
      });

      return {
        certified: true,
        electionId,
        status: 'COMPLETED',
        certifiedAt: now.toISOString(),
        transferredRoles,
        message: 'Election certified successfully. Leadership roles have been officially transferred.',
      };
    });
  }

  /**
   * Triggers a run-off election for a role that resulted in a tie.
   */
  async triggerRunoff(idirId: string, electionId: string, actorUserId: string, input: TriggerRunoffInput) {
    await assertIdirActive(idirId);
    await this.getOfficerOrCommitteeMembership(idirId, electionId, actorUserId);

    const election = await prisma.election.findFirst({
      where: { id: electionId, idirId },
      include: {
        results: { where: { role: input.role } },
        nominations: { where: { role: input.role, status: 'ACCEPTED' } },
      },
    });

    if (!election) {
      throw new NotFoundError('Election not found');
    }

    const roleResult = election.results[0];
    if (roleResult && roleResult.winnerNominationId) {
      throw new BadRequestError(`Role ${input.role} already has a designated winner; run-off is not needed`);
    }

    const now = new Date();
    const runoffEndDate = input.runoffEndDate
      ? new Date(input.runoffEndDate)
      : new Date(now.getTime() + 48 * 60 * 60 * 1000); // default 48h runoff window

    // Reset ballots for this role and clear vote receipts for this role to allow run-off vote
    return await prisma.$transaction(async (tx) => {
      // Delete previous ballots for this role to allow clean run-off vote
      await tx.ballot.deleteMany({
        where: { electionId, role: input.role },
      });

      // Delete vote receipts for this role so members can vote in the run-off
      await tx.voteReceipt.deleteMany({
        where: { electionId, role: input.role },
      });

      // Update election to VOTING for runoff
      await tx.election.update({
        where: { id: electionId },
        data: {
          status: 'VOTING',
          endDate: runoffEndDate,
        },
      });

      await tx.auditLog.create({
        data: {
          actorId: actorUserId,
          idirId,
          action: 'TRIGGER_ELECTION_RUNOFF',
          entityType: 'Election',
          entityId: electionId,
          safeMetadata: {
            role: input.role,
            runoffEndDate: runoffEndDate.toISOString(),
          },
        },
      });

      return {
        runoffActive: true,
        electionId,
        role: input.role,
        runoffEndDate: runoffEndDate.toISOString(),
        message: `Run-off voting initiated for ${input.role}. Members can now cast their run-off ballots until ${runoffEndDate.toISOString()}.`,
      };
    });
  }
}

export const resultsService = new ResultsService();
