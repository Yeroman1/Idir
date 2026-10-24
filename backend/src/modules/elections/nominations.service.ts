import { MembershipRole } from '@prisma/client';
import { prisma } from '../../config/database.js';
import {
  BadRequestError,
  ConflictError,
  ForbiddenError,
  NotFoundError,
} from '../../shared/errors/AppError.js';
import { assertIdirActive } from '../../middleware/assertIdirActive.js';
import {
  CreateNominationInput,
  RespondNominationInput,
  QueryNominationsInput,
} from './nominations.validation.js';

export class NominationsService {
  /**
   * Nominate oneself or a fellow active member for an election role.
   *
   * Enforces:
   * 1. Idir is ACTIVE.
   * 2. Actor and Nominee are ACTIVE members in this Idir.
   * 3. Nominee is NOT a member of the neutral election committee for this election.
   * 4. Nominee meets election tenure and eligibility criteria.
   * 5. Contested role is part of the election configuration.
   * 6. Nomination window is open.
   * 7. Self-nominations are automatically marked ACCEPTED; other-nominations start as PENDING.
   */
  async nominateCandidate(
    idirId: string,
    electionId: string,
    actorUserId: string,
    input: CreateNominationInput
  ) {
    await assertIdirActive(idirId);

    // 1. Fetch actor membership
    const actorMembership = await prisma.membership.findUnique({
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
      },
    });

    if (!actorMembership || actorMembership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not an active member of this Idir');
    }

    // 2. Fetch election
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

    if (election.status === 'COMPLETED' || election.status === 'CANCELLED' || election.status === 'TALLYING') {
      throw new BadRequestError(`Nominations are closed for this election (current status: ${election.status})`);
    }

    const now = new Date();
    if (election.nominationEndDate && now > election.nominationEndDate) {
      throw new BadRequestError('The nomination window for this election has officially closed');
    }

    // Check if role is contested
    if (!election.roles.includes(input.role as MembershipRole)) {
      throw new BadRequestError(
        `The role '${input.role}' is not open for election in this election. Open roles: ${election.roles.join(', ')}`
      );
    }

    // 3. Fetch nominee membership
    const nomineeMembership = await prisma.membership.findFirst({
      where: {
        id: input.nomineeMembershipId,
        idirId,
      },
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

    if (!nomineeMembership || nomineeMembership.status !== 'ACTIVE') {
      throw new BadRequestError(
        'Only active members in good standing can be nominated as candidates'
      );
    }

    // 4. Neutral Election Committee check:
    // Members of the neutral election committee CANNOT be candidates
    const isCommitteeMember = election.committeeMembers.some(
      (cm) => cm.membershipId === nomineeMembership.id
    );
    if (isCommitteeMember) {
      throw new BadRequestError(
        'Members of the neutral election committee are barred from running as candidates in this election'
      );
    }

    // 5. Tenure eligibility check
    if (election.minMembershipTenureDays > 0) {
      const tenureMs = now.getTime() - nomineeMembership.joinedAt.getTime();
      const tenureDays = tenureMs / (1000 * 60 * 60 * 24);
      if (tenureDays < election.minMembershipTenureDays) {
        throw new BadRequestError(
          `Nominee has not fulfilled the minimum tenure requirement of ${election.minMembershipTenureDays} days (current: ${Math.floor(tenureDays)} days)`
        );
      }
    }

    // 6. Check existing nomination for this role
    const existingNomination = await prisma.electionNomination.findUnique({
      where: {
        electionId_role_nomineeMembershipId: {
          electionId,
          role: input.role as MembershipRole,
          nomineeMembershipId: nomineeMembership.id,
        },
      },
    });

    if (existingNomination) {
      if (existingNomination.status === 'PENDING' || existingNomination.status === 'ACCEPTED') {
        throw new ConflictError(
          `This member already has an active or pending nomination for the role '${input.role}'`
        );
      }
    }

    const isSelfNomination = actorMembership.id === nomineeMembership.id;
    const initialStatus = isSelfNomination ? 'ACCEPTED' : 'PENDING';

    return prisma.$transaction(async (tx) => {
      const nomination = await tx.electionNomination.upsert({
        where: {
          electionId_role_nomineeMembershipId: {
            electionId,
            role: input.role as MembershipRole,
            nomineeMembershipId: nomineeMembership.id,
          },
        },
        create: {
          electionId,
          role: input.role as MembershipRole,
          nomineeMembershipId: nomineeMembership.id,
          nominatedByMembershipId: actorMembership.id,
          statement: input.statement ? input.statement.trim() : null,
          status: initialStatus,
          acceptedAt: isSelfNomination ? now : null,
        },
        update: {
          nominatedByMembershipId: actorMembership.id,
          statement: input.statement ? input.statement.trim() : null,
          status: initialStatus,
          acceptedAt: isSelfNomination ? now : null,
          declinedAt: null,
        },
        include: {
          nomineeMembership: {
            select: {
              id: true,
              memberNumber: true,
              user: {
                select: {
                  id: true,
                  fullName: true,
                  phoneNumber: true,
                },
              },
            },
          },
          nominatedByMembership: {
            select: {
              id: true,
              memberNumber: true,
              user: {
                select: {
                  id: true,
                  fullName: true,
                },
              },
            },
          },
        },
      });

      await tx.auditLog.create({
        data: {
          actorId: actorUserId,
          idirId,
          action: 'NOMINATE_CANDIDATE',
          entityType: 'ElectionNomination',
          entityId: nomination.id,
          safeMetadata: {
            role: nomination.role,
            nomineeMembershipId: nomineeMembership.id,
            nomineeName: nomineeMembership.user.fullName,
            isSelfNomination,
            status: nomination.status,
          },
        },
      });

      return nomination;
    });
  }

  /**
   * Nominated member accepts or declines a nomination.
   */
  async respondToNomination(
    idirId: string,
    electionId: string,
    nominationId: string,
    actorUserId: string,
    input: RespondNominationInput
  ) {
    await assertIdirActive(idirId);

    const nomination = await prisma.electionNomination.findFirst({
      where: { id: nominationId, electionId },
      include: {
        nomineeMembership: {
          select: {
            id: true,
            userId: true,
            user: {
              select: {
                fullName: true,
              },
            },
          },
        },
      },
    });

    if (!nomination) {
      throw new NotFoundError('Nomination not found');
    }

    // Only the nominated member can accept or decline
    if (nomination.nomineeMembership.userId !== actorUserId) {
      throw new ForbiddenError(
        'Only the nominated member has authority to accept or decline this nomination'
      );
    }

    if (nomination.status !== 'PENDING') {
      throw new BadRequestError(
        `This nomination has already been processed (current status: ${nomination.status})`
      );
    }

    const now = new Date();
    const isAccepting = input.action === 'ACCEPT';

    return prisma.$transaction(async (tx) => {
      const updated = await tx.electionNomination.update({
        where: { id: nominationId },
        data: {
          status: isAccepting ? 'ACCEPTED' : 'DECLINED',
          acceptedAt: isAccepting ? now : null,
          declinedAt: isAccepting ? null : now,
          ...(input.statement !== undefined
            ? { statement: input.statement.trim() }
            : {}),
        },
        include: {
          nomineeMembership: {
            select: {
              id: true,
              memberNumber: true,
              user: {
                select: {
                  id: true,
                  fullName: true,
                },
              },
            },
          },
        },
      });

      await tx.auditLog.create({
        data: {
          actorId: actorUserId,
          idirId,
          action: isAccepting ? 'ACCEPT_NOMINATION' : 'DECLINE_NOMINATION',
          entityType: 'ElectionNomination',
          entityId: nominationId,
          safeMetadata: {
            role: nomination.role,
            status: updated.status,
          },
        },
      });

      return updated;
    });
  }

  /**
   * Nominee withdraws their candidacy.
   */
  async withdrawNomination(
    idirId: string,
    electionId: string,
    nominationId: string,
    actorUserId: string
  ) {
    await assertIdirActive(idirId);

    const nomination = await prisma.electionNomination.findFirst({
      where: { id: nominationId, electionId },
      include: {
        nomineeMembership: {
          select: {
            id: true,
            userId: true,
          },
        },
      },
    });

    if (!nomination) {
      throw new NotFoundError('Nomination not found');
    }

    if (nomination.nomineeMembership.userId !== actorUserId) {
      throw new ForbiddenError('Only the candidate can withdraw their own nomination');
    }

    if (nomination.status === 'WITHDRAWN' || nomination.status === 'DECLINED') {
      throw new BadRequestError(`Nomination is already ${nomination.status}`);
    }

    return prisma.$transaction(async (tx) => {
      const updated = await tx.electionNomination.update({
        where: { id: nominationId },
        data: { status: 'WITHDRAWN' },
      });

      await tx.auditLog.create({
        data: {
          actorId: actorUserId,
          idirId,
          action: 'WITHDRAW_NOMINATION',
          entityType: 'ElectionNomination',
          entityId: nominationId,
          safeMetadata: { role: nomination.role },
        },
      });

      return updated;
    });
  }

  /**
   * Updates candidate's short statement.
   */
  async updateCandidateStatement(
    idirId: string,
    electionId: string,
    nominationId: string,
    actorUserId: string,
    statement: string
  ) {
    await assertIdirActive(idirId);

    const nomination = await prisma.electionNomination.findFirst({
      where: { id: nominationId, electionId },
      include: {
        nomineeMembership: {
          select: {
            id: true,
            userId: true,
          },
        },
      },
    });

    if (!nomination) {
      throw new NotFoundError('Nomination not found');
    }

    if (nomination.nomineeMembership.userId !== actorUserId) {
      throw new ForbiddenError('Only the candidate can update their statement');
    }

    return prisma.electionNomination.update({
      where: { id: nominationId },
      data: { statement: statement.trim() },
    });
  }

  /**
   * Retrieves nominations for an election.
   *
   * Crucial acceptance criteria:
   * "unaccepted nominations don’t appear on the ballot."
   * When ballotOnly is true (or by default for voting), ONLY nominations with status 'ACCEPTED' are returned.
   */
  async listNominations(
    idirId: string,
    electionId: string,
    actorUserId: string,
    query: QueryNominationsInput
  ) {
    await assertIdirActive(idirId);

    // Verify actor is an active member
    const actorMembership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId: actorUserId,
        },
      },
    });

    if (!actorMembership || actorMembership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not an active member of this Idir');
    }

    // Default to ballotOnly / ACCEPTED unless explicitly requesting ALL or specific status
    let statusFilter: any = 'ACCEPTED';
    if (query.ballotOnly || (!query.status && query.ballotOnly !== false)) {
      statusFilter = 'ACCEPTED';
    } else if (query.status) {
      if (query.status === 'ALL') {
        statusFilter = undefined;
      } else {
        statusFilter = query.status;
      }
    }

    return prisma.electionNomination.findMany({
      where: {
        electionId,
        ...(query.role ? { role: query.role as MembershipRole } : {}),
        ...(statusFilter ? { status: statusFilter } : {}),
      },
      orderBy: [{ role: 'asc' }, { createdAt: 'asc' }],
      include: {
        nomineeMembership: {
          select: {
            id: true,
            memberNumber: true,
            joinedAt: true,
            user: {
              select: {
                id: true,
                fullName: true,
                phoneNumber: true,
              },
            },
          },
        },
        nominatedByMembership: {
          select: {
            id: true,
            memberNumber: true,
            user: {
              select: {
                id: true,
                fullName: true,
              },
            },
          },
        },
      },
    });
  }

  /**
   * Retrieves full candidate page details.
   */
  async getCandidatePage(
    idirId: string,
    electionId: string,
    nominationId: string,
    actorUserId: string
  ) {
    await assertIdirActive(idirId);

    const actorMembership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId: actorUserId,
        },
      },
    });

    if (!actorMembership || actorMembership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not an active member of this Idir');
    }

    const nomination = await prisma.electionNomination.findFirst({
      where: { id: nominationId, electionId },
      include: {
        election: {
          select: {
            id: true,
            title: true,
            termLengthMonths: true,
            startDate: true,
            endDate: true,
            status: true,
          },
        },
        nomineeMembership: {
          select: {
            id: true,
            memberNumber: true,
            joinedAt: true,
            user: {
              select: {
                id: true,
                fullName: true,
                phoneNumber: true,
              },
            },
          },
        },
        nominatedByMembership: {
          select: {
            id: true,
            memberNumber: true,
            user: {
              select: {
                id: true,
                fullName: true,
              },
            },
          },
        },
      },
    });

    if (!nomination) {
      throw new NotFoundError('Candidate page not found');
    }

    return nomination;
  }
}

export const nominationsService = new NominationsService();
