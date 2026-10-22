import { MembershipRole, Prisma } from '@prisma/client';
import { prisma } from '../../config/database.js';
import {
  BadRequestError,
  ForbiddenError,
  NotFoundError,
} from '../../shared/errors/AppError.js';
import { assertIdirActive } from '../../middleware/assertIdirActive.js';
import {
  CreateElectionInput,
  UpdateElectionInput,
  QueryElectionsInput,
} from './elections.validation.js';

export const ALLOWED_ELECTION_OFFICER_ROLES: MembershipRole[] = [
  'CREATOR',
  'CHAIRPERSON',
  'OFFICER',
  'SECRETARY',
  'COMMITTEE',
];

export class ElectionsService {
  /**
   * Creates an election for an Idir.
   *
   * Enforces:
   * 1. Idir exists and is in ACTIVE status.
   * 2. Actor has an ACTIVE membership with an authorized leadership role.
   * 3. Neutral Election Committee validation:
   *    - All specified committee members must have ACTIVE memberships in this Idir.
   *    - Committee members cannot be candidates in this election.
   * 4. Persists the election, election committee assignments, and an immutable audit log entry.
   */
  async createElection(idirId: string, actorId: string, input: CreateElectionInput) {
    // 1. Verify Idir is active
    await assertIdirActive(idirId);

    // 2. Verify actor permissions
    const actorMembership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId: actorId,
        },
      },
      select: {
        id: true,
        role: true,
        status: true,
      },
    });

    if (
      !actorMembership ||
      actorMembership.status !== 'ACTIVE' ||
      !ALLOWED_ELECTION_OFFICER_ROLES.includes(actorMembership.role)
    ) {
      throw new ForbiddenError(
        'Only authorized officers (Chairperson, Creator, Secretary, or Committee) can create an election'
      );
    }

    // 3. Verify Neutral Election Committee members
    const committeeMemberships = await prisma.membership.findMany({
      where: {
        id: { in: input.committeeMemberIds },
        idirId,
        status: 'ACTIVE',
      },
      select: {
        id: true,
        userId: true,
        role: true,
        memberNumber: true,
        user: {
          select: {
            id: true,
            fullName: true,
            phoneNumber: true,
          },
        },
      },
    });

    if (committeeMemberships.length !== input.committeeMemberIds.length) {
      const foundIds = new Set(committeeMemberships.map((m) => m.id));
      const missingIds = input.committeeMemberIds.filter((id) => !foundIds.has(id));
      throw new BadRequestError(
        `All election committee members must be active members of this Idir. Invalid or inactive member IDs: ${missingIds.join(', ')}`
      );
    }

    // Determine initial status based on dates
    const now = new Date();
    let initialStatus: 'DRAFT' | 'NOMINATING' | 'VOTING' = 'DRAFT';
    if (input.nominationStartDate && input.nominationStartDate <= now && (!input.nominationEndDate || input.nominationEndDate > now)) {
      initialStatus = 'NOMINATING';
    } else if (input.startDate <= now && input.endDate > now) {
      initialStatus = 'VOTING';
    }

    // 4. Atomic transaction to create election, committee members, and audit log
    return prisma.$transaction(async (tx) => {
      const election = await tx.election.create({
        data: {
          idirId,
          title: input.title.trim(),
          description: input.description ? input.description.trim() : null,
          roles: input.roles as MembershipRole[],
          startDate: input.startDate,
          endDate: input.endDate,
          nominationStartDate: input.nominationStartDate,
          nominationEndDate: input.nominationEndDate,
          termLengthMonths: input.termLengthMonths,
          votingMethod: input.votingMethod,
          ballotType: input.ballotType,
          quorumPercentage: new Prisma.Decimal(input.quorumPercentage),
          minMembershipTenureDays: input.minMembershipTenureDays ?? 0,
          requiresGoodStanding: input.requiresGoodStanding ?? true,
          disputeWindowHours: input.disputeWindowHours ?? 48,
          handoverDate: input.handoverDate,
          status: initialStatus,
          createdById: actorId,
          committeeMembers: {
            create: input.committeeMemberIds.map((membershipId) => ({
              membershipId,
              role: 'COMMITTEE_MEMBER',
            })),
          },
        },
        include: {
          committeeMembers: {
            include: {
              membership: {
                select: {
                  id: true,
                  memberNumber: true,
                  role: true,
                  user: {
                    select: {
                      id: true,
                      fullName: true,
                      phoneNumber: true,
                    },
                  },
                },
              },
            },
          },
          createdBy: {
            select: {
              id: true,
              fullName: true,
              phoneNumber: true,
            },
          },
        },
      });

      // 5. Immutable Audit Log record
      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'CREATE_ELECTION',
          entityType: 'Election',
          entityId: election.id,
          safeMetadata: {
            title: election.title,
            roles: election.roles,
            startDate: election.startDate ? new Date(election.startDate).toISOString() : undefined,
            endDate: election.endDate ? new Date(election.endDate).toISOString() : undefined,
            termLengthMonths: election.termLengthMonths,
            votingMethod: election.votingMethod,
            ballotType: election.ballotType,
            quorumPercentage: election.quorumPercentage ? election.quorumPercentage.toString() : '50.00',
            committeeMembersCount: input.committeeMemberIds.length,
          },
        },
      });

      return election;
    });
  }

  /**
   * Retrieves an election by ID with committee and setup details.
   */
  async getElectionById(idirId: string, electionId: string, actorId: string) {
    const membership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId: actorId,
        },
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not an active member of this Idir');
    }

    const election = await prisma.election.findFirst({
      where: {
        id: electionId,
        idirId,
      },
      include: {
        committeeMembers: {
          include: {
            membership: {
              select: {
                id: true,
                memberNumber: true,
                role: true,
                user: {
                  select: {
                    id: true,
                    fullName: true,
                    phoneNumber: true,
                  },
                },
              },
            },
          },
        },
        nominations: {
          select: {
            id: true,
            role: true,
            status: true,
            statement: true,
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
          },
        },
        results: true,
        createdBy: {
          select: {
            id: true,
            fullName: true,
          },
        },
      },
    });

    if (!election) {
      throw new NotFoundError('Election not found');
    }

    return election;
  }

  /**
   * Lists elections for an Idir with optional status filter and pagination.
   */
  async listIdirElections(idirId: string, actorId: string, query: QueryElectionsInput) {
    const membership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId: actorId,
        },
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError('You are not an active member of this Idir');
    }

    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: Prisma.ElectionWhereInput = {
      idirId,
      ...(query.status ? { status: query.status } : {}),
    };

    const [items, total] = await Promise.all([
      prisma.election.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          committeeMembers: {
            include: {
              membership: {
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
          },
          _count: {
            select: {
              nominations: true,
              voteReceipts: true,
            },
          },
        },
      }),
      prisma.election.count({ where }),
    ]);

    return {
      items,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Updates an election's settings while still in DRAFT status.
   */
  async updateElection(
    idirId: string,
    electionId: string,
    actorId: string,
    input: UpdateElectionInput
  ) {
    const actorMembership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId: actorId,
        },
      },
    });

    if (
      !actorMembership ||
      actorMembership.status !== 'ACTIVE' ||
      !ALLOWED_ELECTION_OFFICER_ROLES.includes(actorMembership.role)
    ) {
      throw new ForbiddenError('Only authorized officers can update election settings');
    }

    const election = await prisma.election.findFirst({
      where: { id: electionId, idirId },
    });

    if (!election) {
      throw new NotFoundError('Election not found');
    }

    if (election.status !== 'DRAFT') {
      throw new BadRequestError(
        `Cannot modify election settings once the election has advanced beyond DRAFT (current status: ${election.status})`
      );
    }

    if (input.committeeMemberIds) {
      const committeeMemberships = await prisma.membership.findMany({
        where: {
          id: { in: input.committeeMemberIds },
          idirId,
          status: 'ACTIVE',
        },
      });

      if (committeeMemberships.length !== input.committeeMemberIds.length) {
        throw new BadRequestError(
          'All election committee members must be active members of this Idir'
        );
      }
    }

    return prisma.$transaction(async (tx) => {
      if (input.committeeMemberIds) {
        await tx.electionCommitteeMember.deleteMany({
          where: { electionId },
        });
        await tx.electionCommitteeMember.createMany({
          data: input.committeeMemberIds.map((membershipId) => ({
            electionId,
            membershipId,
            role: 'COMMITTEE_MEMBER',
          })),
        });
      }

      const updated = await tx.election.update({
        where: { id: electionId },
        data: {
          ...(input.title ? { title: input.title.trim() } : {}),
          ...(input.description !== undefined ? { description: input.description?.trim() || null } : {}),
          ...(input.roles ? { roles: input.roles as MembershipRole[] } : {}),
          ...(input.startDate ? { startDate: input.startDate } : {}),
          ...(input.endDate ? { endDate: input.endDate } : {}),
          ...(input.termLengthMonths ? { termLengthMonths: input.termLengthMonths } : {}),
          ...(input.votingMethod ? { votingMethod: input.votingMethod } : {}),
          ...(input.ballotType ? { ballotType: input.ballotType } : {}),
          ...(input.quorumPercentage ? { quorumPercentage: new Prisma.Decimal(input.quorumPercentage) } : {}),
          ...(input.minMembershipTenureDays !== undefined
            ? { minMembershipTenureDays: input.minMembershipTenureDays }
            : {}),
          ...(input.requiresGoodStanding !== undefined
            ? { requiresGoodStanding: input.requiresGoodStanding }
            : {}),
          ...(input.disputeWindowHours ? { disputeWindowHours: input.disputeWindowHours } : {}),
          ...(input.handoverDate ? { handoverDate: input.handoverDate } : {}),
        },
        include: {
          committeeMembers: {
            include: {
              membership: {
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
          },
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'UPDATE_ELECTION',
          entityType: 'Election',
          entityId: electionId,
          safeMetadata: {
            updatedFields: Object.keys(input),
          },
        },
      });

      return updated;
    });
  }

  /**
   * Cancels an election with a logged reason.
   */
  async cancelElection(
    idirId: string,
    electionId: string,
    actorId: string,
    reason: string
  ) {
    const actorMembership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId: actorId,
        },
      },
    });

    if (
      !actorMembership ||
      actorMembership.status !== 'ACTIVE' ||
      !ALLOWED_ELECTION_OFFICER_ROLES.includes(actorMembership.role)
    ) {
      throw new ForbiddenError('Only authorized officers can cancel an election');
    }

    const election = await prisma.election.findFirst({
      where: { id: electionId, idirId },
    });

    if (!election) {
      throw new NotFoundError('Election not found');
    }

    if (election.status === 'COMPLETED' || election.status === 'CANCELLED') {
      throw new BadRequestError(`Cannot cancel an election that is already ${election.status}`);
    }

    return prisma.$transaction(async (tx) => {
      const cancelled = await tx.election.update({
        where: { id: electionId },
        data: {
          status: 'CANCELLED',
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'CANCEL_ELECTION',
          entityType: 'Election',
          entityId: electionId,
          safeMetadata: {
            reason,
            previousStatus: election.status,
          },
        },
      });

      return cancelled;
    });
  }
}

export const electionsService = new ElectionsService();
