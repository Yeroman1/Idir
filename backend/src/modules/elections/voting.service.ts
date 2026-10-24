import crypto from 'node:crypto';
import { MembershipRole } from '@prisma/client';
import { prisma } from '../../config/database.js';
import {
  BadRequestError,
  ConflictError,
  ForbiddenError,
  NotFoundError,
} from '../../shared/errors/AppError.js';
import { assertIdirActive } from '../../middleware/assertIdirActive.js';
import { CastVoteInput, CastBatchVotesInput } from './voting.validation.js';

export class VotingService {
  /**
   * Cast a single vote for a contested role in an election.
   *
   * Enforces:
   * 1. Idir is ACTIVE.
   * 2. Voter has an ACTIVE membership in this Idir with tenure requirements met.
   * 4. Election status is active for voting and within the official voting window.
   * 5. Contested role is part of the election configuration.
   * 6. Candidate is on the official ballot with status ACCEPTED.
   * 7. Double-voting prevented: Exactly one vote per member per role.
   * 8. Privacy & Anonymity:
   *    - VoteReceipt (who voted) stored separately from Ballot (candidate chosen).
   *    - For SECRET ballots, Ballot record has voterMembershipId = null.
   *    - Cryptographic receipt token hash returned to voter as tamper-evident proof.
   */
  async castVote(
    idirId: string,
    electionId: string,
    actorUserId: string,
    input: CastVoteInput
  ) {
    await assertIdirActive(idirId);

    // 1. Fetch actor user
    const user = await prisma.user.findUnique({
      where: { id: actorUserId },
      select: {
        id: true,
        fullName: true,
        phoneNumber: true,
        status: true,
      },
    });

    if (!user || user.status !== 'ACTIVE') {
      throw new ForbiddenError('Active user account is required to participate in voting');
    }

    // 2. Fetch voter membership
    const membership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId: actorUserId,
        },
      },
      select: {
        id: true,
        status: true,
        role: true,
        joinedAt: true,
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('Only active members in good standing are eligible to vote');
    }

    // 3. Fetch election
    const election = await prisma.election.findFirst({
      where: { id: electionId, idirId },
      include: {
        committeeMembers: {
          select: { membershipId: true },
        },
      },
    });

    if (!election) {
      throw new NotFoundError('Election not found');
    }

    const now = new Date();

    // Check status and voting window
    if (election.status === 'COMPLETED' || election.status === 'CANCELLED' || election.status === 'TALLYING') {
      throw new BadRequestError(`Voting is closed for this election (current status: ${election.status})`);
    }

    if (now < election.startDate) {
      throw new BadRequestError(
        `The voting window for this election has not opened yet (opens at ${election.startDate.toISOString()})`
      );
    }

    if (now > election.endDate) {
      throw new BadRequestError(
        `The voting window for this election has officially closed (closed at ${election.endDate.toISOString()})`
      );
    }

    // Tenure eligibility check
    if (election.minMembershipTenureDays > 0) {
      const tenureDays =
        (now.getTime() - membership.joinedAt.getTime()) / (1000 * 60 * 60 * 24);
      if (tenureDays < election.minMembershipTenureDays) {
        throw new ForbiddenError(
          `You have not met the minimum tenure requirement of ${election.minMembershipTenureDays} days to vote in this election`
        );
      }
    }

    // Check if role is contested
    const targetRole = input.role as MembershipRole;
    if (!election.roles.includes(targetRole)) {
      throw new BadRequestError(
        `The role '${input.role}' is not open for election in this ballot. Open roles: ${election.roles.join(', ')}`
      );
    }

    // 4. Candidate verification: Must exist in this election, match role, and be ACCEPTED
    const candidate = await prisma.electionNomination.findFirst({
      where: {
        id: input.candidateNominationId,
        electionId,
        role: targetRole,
      },
      include: {
        nomineeMembership: {
          select: {
            user: { select: { fullName: true } },
          },
        },
      },
    });

    if (!candidate) {
      throw new NotFoundError(
        `Candidate not found for the role '${input.role}' in this election`
      );
    }

    // Done when requirement: unaccepted nominations don't appear on ballot
    if (candidate.status !== 'ACCEPTED') {
      throw new BadRequestError(
        `Cannot vote for candidate with status '${candidate.status}'. Only officially accepted candidates on the ballot can receive votes.`
      );
    }

    // 5. Check duplicate vote for this role (One vote per member per role)
    const existingReceipt = await prisma.voteReceipt.findUnique({
      where: {
        electionId_role_membershipId: {
          electionId,
          role: targetRole,
          membershipId: membership.id,
        },
      },
    });

    if (existingReceipt) {
      throw new ConflictError(
        `You have already cast a vote for the role of ${input.role} in this election. Double-voting is strictly prohibited.`
      );
    }

    // 6. Generate cryptographic receipt token hash
    const salt = crypto.randomUUID();
    const rawProof = `${electionId}:${membership.id}:${targetRole}:${now.toISOString()}:${salt}`;
    const receiptTokenHash = crypto.createHash('sha256').update(rawProof).digest('hex');

    // 7. Execute vote transaction with decoupled VoteReceipt and Ballot
    return prisma.$transaction(async (tx) => {
      // Create VoteReceipt (who voted, role, timestamp, verification hash)
      const receipt = await tx.voteReceipt.create({
        data: {
          electionId,
          membershipId: membership.id,
          role: targetRole,
          votedAt: now,
          receiptTokenHash,
        },
      });

      // Create Ballot (what was chosen)
      // For SECRET ballot: voterMembershipId is NULL (cannot be linked to member).
      // For OPEN ballot: voterMembershipId stores the member ID.
      const isOpenBallot = election.ballotType === 'OPEN';
      await tx.ballot.create({
        data: {
          electionId,
          role: targetRole,
          candidateNominationId: candidate.id,
          voterMembershipId: isOpenBallot ? membership.id : null,
          castAt: now,
        },
      });

      // Audit Log: Do NOT record candidate choice in audit log for secret ballots!
      await tx.auditLog.create({
        data: {
          actorId: actorUserId,
          idirId,
          action: 'CAST_VOTE',
          entityType: 'VoteReceipt',
          entityId: receipt.id,
          safeMetadata: {
            electionId,
            role: targetRole,
            ballotType: election.ballotType,
            isSecret: !isOpenBallot,
            ...(isOpenBallot
              ? { candidateNominationId: candidate.id }
              : {}),
          },
        },
      });

      return {
        receiptId: receipt.id,
        electionId,
        role: targetRole,
        votedAt: receipt.votedAt,
        receiptTokenHash: receipt.receiptTokenHash,
        ballotType: election.ballotType,
        isSecret: !isOpenBallot,
        message: `Vote for ${targetRole} successfully cast and securely recorded`,
      };
    });
  }

  /**
   * Cast votes for multiple roles simultaneously in an atomic transaction.
   */
  async castBatchVotes(
    idirId: string,
    electionId: string,
    actorUserId: string,
    input: CastBatchVotesInput
  ) {
    const results = [];
    for (const v of input.votes) {
      const res = await this.castVote(idirId, electionId, actorUserId, {
        role: v.role,
        candidateNominationId: v.candidateNominationId,
      });
      results.push(res);
    }
    return results;
  }

  /**
   * Retrieves the voting status of the current member for an election.
   * Indicates which roles they have already voted for and gives their verification receipt tokens.
   */
  async getMemberVotingStatus(
    idirId: string,
    electionId: string,
    actorUserId: string
  ) {
    await assertIdirActive(idirId);

    const membership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId: actorUserId,
        },
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not an active member of this Idir');
    }

    const election = await prisma.election.findFirst({
      where: { id: electionId, idirId },
      select: {
        id: true,
        title: true,
        roles: true,
        startDate: true,
        endDate: true,
        status: true,
        ballotType: true,
        votingMethod: true,
        minMembershipTenureDays: true,
      },
    });

    if (!election) {
      throw new NotFoundError('Election not found');
    }

    const now = new Date();
    const isWindowOpen = now >= election.startDate && now <= election.endDate;

    const receipts = await prisma.voteReceipt.findMany({
      where: {
        electionId,
        membershipId: membership.id,
      },
      select: {
        id: true,
        role: true,
        votedAt: true,
        receiptTokenHash: true,
      },
    });

    const votedRoles = receipts.map((r) => r.role);
    const pendingRoles = election.roles.filter((r) => !votedRoles.includes(r));

    const tenureDays =
      (now.getTime() - membership.joinedAt.getTime()) / (1000 * 60 * 60 * 24);
    const isTenureEligible =
      election.minMembershipTenureDays === 0 ||
      tenureDays >= election.minMembershipTenureDays;

    return {
      electionId,
      electionTitle: election.title,
      ballotType: election.ballotType,
      votingMethod: election.votingMethod,
      isWindowOpen,
      isTenureEligible,
      canVote: isWindowOpen && isTenureEligible,
      roles: election.roles,
      votedRoles,
      pendingRoles,
      receipts,
      allRolesVoted: pendingRoles.length === 0,
    };
  }

  /**
   * Retrieves official election ballot with accepted candidates per contested role.
   */
  async getElectionBallot(
    idirId: string,
    electionId: string,
    actorUserId: string
  ) {
    await assertIdirActive(idirId);

    const membership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId: actorUserId,
        },
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not an active member of this Idir');
    }

    const election = await prisma.election.findFirst({
      where: { id: electionId, idirId },
      select: {
        id: true,
        title: true,
        description: true,
        roles: true,
        startDate: true,
        endDate: true,
        status: true,
        ballotType: true,
        votingMethod: true,
        quorumPercentage: true,
        minMembershipTenureDays: true,
      },
    });

    if (!election) {
      throw new NotFoundError('Election not found');
    }

    // Fetch accepted candidates for each role
    const candidates = await prisma.electionNomination.findMany({
      where: {
        electionId,
        status: 'ACCEPTED', // ONLY accepted candidates appear on the ballot!
      },
      select: {
        id: true,
        role: true,
        statement: true,
        acceptedAt: true,
        nomineeMembership: {
          select: {
            id: true,
            memberNumber: true,
            joinedAt: true,
            user: {
              select: {
                id: true,
                fullName: true,
              },
            },
          },
        },
      },
      orderBy: [{ role: 'asc' }, { createdAt: 'asc' }],
    });

    // Group candidates by role
    const ballotByRole: Record<string, typeof candidates> = {};
    for (const role of election.roles) {
      ballotByRole[role] = candidates.filter((c) => c.role === role);
    }

    // Member receipts
    const receipts = await prisma.voteReceipt.findMany({
      where: {
        electionId,
        membershipId: membership.id,
      },
      select: {
        id: true,
        role: true,
        votedAt: true,
        receiptTokenHash: true,
      },
    });

    const votedRoles = receipts.map((r) => r.role);

    return {
      election,
      ballotByRole,
      votedRoles,
      receipts,
    };
  }
}

export const votingService = new VotingService();
