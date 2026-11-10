import { Prisma, CooperationStatus, JointInitiativeStatus, CrossIdirAnnouncementCategory, CrossIdirEmergencyStatus, CrossIdirEmergencyUrgency, JointFinancialCommitmentStatus } from '@prisma/client';
import { prisma } from '../../config/database.js';
import { AppError, ForbiddenError, NotFoundError } from '../../shared/errors/AppError.js';
import { logger } from '../../shared/utils/logger.js';
import type {
  ProposeCooperationInput,
  RespondCooperationInput,
  EndCooperationInput,
  CreateInitiativeInput,
  UpdateInitiativeInput,
  AddInitiativeUpdateInput,
  AddInitiativeTaskInput,
  CreateCrossAnnouncementInput,
  UpdateCrossAnnouncementInput,
  CreateCrossEmergencyInput,
  RespondCrossEmergencyInput,
  CloseCrossEmergencyInput,
  CreateFinancialCommitmentInput,
  ConfirmFinancialCommitmentInput,
} from './cooperation.validation.js';

export const COOPERATION_LEADERS = ['CHAIRPERSON', 'CREATOR', 'OFFICER'];
export const INITIATIVE_MANAGERS = ['CHAIRPERSON', 'CREATOR', 'OFFICER', 'SECRETARY', 'COMMITTEE'];
export const FINANCIAL_OFFICERS = ['CHAIRPERSON', 'TREASURER', 'CREATOR'];

export class CooperationService {
  /**
   * Helper to verify agreement exists and the given idirId is an authorized participant.
   */
  async assertParticipant(agreementId: string, idirId: string, requireActive = false) {
    const agreement = await prisma.cooperationAgreement.findUnique({
      where: { id: agreementId },
      include: {
        idirA: { select: { id: true, name: true } },
        idirB: { select: { id: true, name: true } },
        participants: {
          include: {
            idir: { select: { id: true, name: true } },
            authorizedBy: { select: { id: true, fullName: true } },
          },
        },
      },
    });

    if (!agreement) {
      throw new NotFoundError('Cooperation agreement not found');
    }

    const isParticipant =
      agreement.idirAId === idirId ||
      agreement.idirBId === idirId ||
      agreement.participants.some((p) => p.idirId === idirId);

    if (!isParticipant) {
      logger.warn(
        { event: 'CROSS_IDIR_VIOLATION', agreementId, attemptedIdirId: idirId },
        'Cross-Idir Security: Non-participating Idir attempted to access agreement'
      );
      throw new ForbiddenError('You do not have access to this cross-Idir cooperation agreement');
    }

    if (requireActive && agreement.status !== CooperationStatus.ACTIVE) {
      throw new AppError(
        `Cooperation agreement is currently ${agreement.status}. Active status required for this action.`,
        400,
        'AGREEMENT_NOT_ACTIVE'
      );
    }

    return agreement;
  }

  // ── 1. Cooperation Requests ──────────────────────────────────────────────────

  async listAgreements(idirId: string) {
    const agreements = await prisma.cooperationAgreement.findMany({
      where: {
        OR: [
          { idirAId: idirId },
          { idirBId: idirId },
          { participants: { some: { idirId } } },
        ],
      },
      include: {
        idirA: { select: { id: true, name: true } },
        idirB: { select: { id: true, name: true } },
        participants: {
          include: {
            idir: { select: { id: true, name: true } },
            authorizedBy: { select: { id: true, fullName: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return agreements.map((a) => this._formatAgreement(a));
  }

  async getAgreement(idirId: string, agreementId: string) {
    const agreement = await this.assertParticipant(agreementId, idirId);
    return this._formatAgreement(agreement);
  }

  async proposeCooperation(idirId: string, input: ProposeCooperationInput, actorId: string) {
    if (idirId === input.targetIdirId) {
      throw new AppError('An Idir cannot propose cooperation with itself', 400, 'SELF_COOPERATION_NOT_ALLOWED');
    }

    // Verify target Idir exists and is active
    const targetIdir = await prisma.idir.findUnique({
      where: { id: input.targetIdirId },
      select: { id: true, name: true, status: true },
    });

    if (!targetIdir) {
      throw new NotFoundError('Target Idir for cooperation does not exist');
    }

    // Check for existing pending or active agreement between these two Idirs
    const existing = await prisma.cooperationAgreement.findFirst({
      where: {
        status: { in: [CooperationStatus.PENDING, CooperationStatus.ACTIVE] },
        OR: [
          { idirAId: idirId, idirBId: input.targetIdirId },
          { idirAId: input.targetIdirId, idirBId: idirId },
        ],
      },
    });

    if (existing) {
      throw new AppError(
        'An active or pending cooperation agreement already exists between these Idirs',
        400,
        'DUPLICATE_AGREEMENT'
      );
    }

    const proposingIdir = await prisma.idir.findUnique({
      where: { id: idirId },
      select: { id: true, name: true },
    });

    const agreement = await prisma.$transaction(async (tx) => {
      const created = await tx.cooperationAgreement.create({
        data: {
          idirAId: idirId,
          idirBId: input.targetIdirId,
          purpose: input.purpose,
          description: input.description,
          proposedDuration: input.proposedDuration,
          status: CooperationStatus.PENDING,
          createdById: actorId,
        },
      });

      // Participant A (Proposer - already accepted by creator)
      await tx.cooperationParticipant.create({
        data: {
          agreementId: created.id,
          idirId,
          status: CooperationStatus.ACTIVE,
          authorizedById: actorId,
          authorizedAt: new Date(),
        },
      });

      // Participant B (Receiving - pending review)
      await tx.cooperationParticipant.create({
        data: {
          agreementId: created.id,
          idirId: input.targetIdirId,
          status: CooperationStatus.PENDING,
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'PROPOSE_COOPERATION',
          entityType: 'CooperationAgreement',
          entityId: created.id,
          safeMetadata: {
            targetIdirId: input.targetIdirId,
            purpose: input.purpose,
            proposedDuration: input.proposedDuration,
          },
        },
      });

      return created;
    });

    // Notify target Idir leadership
    try {
      const targetLeaders = await prisma.membership.findMany({
        where: {
          idirId: input.targetIdirId,
          role: { in: ['CHAIRPERSON', 'CREATOR', 'OFFICER'] as any },
          status: 'ACTIVE',
        },
        select: { userId: true },
      });

      if (targetLeaders.length > 0) {
        await prisma.notification.createMany({
          data: targetLeaders.map((leader) => ({
            userId: leader.userId,
            title: 'New Cross-Idir Cooperation Proposal',
            body: `${proposingIdir?.name ?? 'An Idir'} proposed cooperation: "${input.purpose}". Review and respond.`,
            type: 'ANNOUNCEMENT',
            data: { idirId: input.targetIdirId, agreementId: agreement.id },
          })),
        });
      }
    } catch (err) {
      logger.error({ err }, 'Failed to dispatch cooperation proposal notification');
    }

    return this.getAgreement(idirId, agreement.id);
  }

  async respondToCooperation(
    idirId: string,
    agreementId: string,
    input: RespondCooperationInput,
    actorId: string
  ) {
    const agreement = await this.assertParticipant(agreementId, idirId);

    if (agreement.status !== CooperationStatus.PENDING) {
      throw new AppError(
        `Cannot respond to an agreement with status ${agreement.status}`,
        400,
        'INVALID_STATUS_TRANSITION'
      );
    }

    const isReceiving = agreement.idirBId === idirId;
    if (!isReceiving) {
      throw new ForbiddenError('Only the receiving Idir can accept or reject this cooperation proposal');
    }

    const action = input.action.toLowerCase();
    const isAccept = action === 'accept';

    await prisma.$transaction(async (tx) => {
      await tx.cooperationParticipant.update({
        where: {
          agreementId_idirId: {
            agreementId,
            idirId,
          },
        },
        data: {
          status: isAccept ? CooperationStatus.ACTIVE : CooperationStatus.REJECTED,
          authorizedById: actorId,
          authorizedAt: new Date(),
          rejectionReason: !isAccept ? input.rejectionReason : null,
        },
      });

      await tx.cooperationAgreement.update({
        where: { id: agreementId },
        data: {
          status: isAccept ? CooperationStatus.ACTIVE : CooperationStatus.REJECTED,
          startDate: isAccept ? new Date() : null,
          endReason: !isAccept ? input.rejectionReason : null,
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: isAccept ? 'ACCEPT_COOPERATION' : 'REJECT_COOPERATION',
          entityType: 'CooperationAgreement',
          entityId: agreementId,
          safeMetadata: {
            action,
            rejectionReason: input.rejectionReason,
          },
        },
      });
    });

    // Notify proposing Idir leadership of decision
    try {
      const proposingLeaders = await prisma.membership.findMany({
        where: {
          idirId: agreement.idirAId,
          role: { in: ['CHAIRPERSON', 'CREATOR', 'OFFICER'] as any },
          status: 'ACTIVE',
        },
        select: { userId: true },
      });

      if (proposingLeaders.length > 0) {
        await prisma.notification.createMany({
          data: proposingLeaders.map((leader) => ({
            userId: leader.userId,
            title: `Cooperation Proposal ${isAccept ? 'Accepted' : 'Declined'}`,
            body: `${agreement.idirB.name} has ${isAccept ? 'accepted' : 'declined'} your cooperation proposal.`,
            type: 'ANNOUNCEMENT',
            data: { idirId: agreement.idirAId, agreementId },
          })),
        });
      }
    } catch (err) {
      logger.error({ err }, 'Failed to dispatch cooperation response notification');
    }

    return this.getAgreement(idirId, agreementId);
  }

  async endCooperation(idirId: string, agreementId: string, input: EndCooperationInput, actorId: string) {
    const agreement = await this.assertParticipant(agreementId, idirId, true);

    await prisma.$transaction(async (tx) => {
      await tx.cooperationAgreement.update({
        where: { id: agreementId },
        data: {
          status: CooperationStatus.COMPLETED,
          endDate: new Date(),
          endReason: input.reason,
        },
      });

      await tx.cooperationParticipant.updateMany({
        where: { agreementId },
        data: { status: CooperationStatus.COMPLETED },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'END_COOPERATION',
          entityType: 'CooperationAgreement',
          entityId: agreementId,
          safeMetadata: { reason: input.reason },
        },
      });
    });

    return this.getAgreement(idirId, agreementId);
  }

  // ── 2. Joint Community Initiatives ──────────────────────────────────────────

  async listInitiatives(idirId: string, agreementId: string) {
    await this.assertParticipant(agreementId, idirId);

    const initiatives = await prisma.jointInitiative.findMany({
      where: { agreementId },
      include: {
        ownerIdir: { select: { id: true, name: true } },
        updates: {
          include: { createdBy: { select: { id: true, fullName: true } } },
          orderBy: { createdAt: 'desc' },
        },
        tasks: {
          include: {
            responsibleIdir: { select: { id: true, name: true } },
            completedBy: { select: { id: true, fullName: true } },
          },
          orderBy: { createdAt: 'asc' },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return initiatives.map((i) => this._formatInitiative(i));
  }

  async getInitiative(idirId: string, agreementId: string, initiativeId: string) {
    await this.assertParticipant(agreementId, idirId);

    const initiative = await prisma.jointInitiative.findFirst({
      where: { id: initiativeId, agreementId },
      include: {
        ownerIdir: { select: { id: true, name: true } },
        updates: {
          include: { createdBy: { select: { id: true, fullName: true } } },
          orderBy: { createdAt: 'desc' },
        },
        tasks: {
          include: {
            responsibleIdir: { select: { id: true, name: true } },
            completedBy: { select: { id: true, fullName: true } },
          },
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    if (!initiative) {
      throw new NotFoundError('Joint initiative not found');
    }

    return this._formatInitiative(initiative);
  }

  async createInitiative(idirId: string, agreementId: string, input: CreateInitiativeInput, actorId: string) {
    await this.assertParticipant(agreementId, idirId, true);

    const initiative = await prisma.$transaction(async (tx) => {
      const created = await tx.jointInitiative.create({
        data: {
          agreementId,
          title: input.title,
          description: input.description,
          objectives: input.objectives,
          category: (input.category as any) || 'OTHER',
          status: JointInitiativeStatus.ACTIVE,
          ownerIdirId: idirId,
          startDate: input.startDate ? new Date(input.startDate) : null,
          endDate: input.endDate ? new Date(input.endDate) : null,
          createdById: actorId,
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'CREATE_JOINT_INITIATIVE',
          entityType: 'JointInitiative',
          entityId: created.id,
          safeMetadata: { title: input.title, category: input.category },
        },
      });

      return created;
    });

    return this.getInitiative(idirId, agreementId, initiative.id);
  }

  async updateInitiative(
    idirId: string,
    agreementId: string,
    initiativeId: string,
    input: UpdateInitiativeInput,
    actorId: string
  ) {
    await this.assertParticipant(agreementId, idirId, true);

    const initiative = await prisma.jointInitiative.findFirst({
      where: { id: initiativeId, agreementId },
    });

    if (!initiative) {
      throw new NotFoundError('Joint initiative not found');
    }

    const updated = await prisma.$transaction(async (tx) => {
      const item = await tx.jointInitiative.update({
        where: { id: initiativeId },
        data: {
          ...(input.title && { title: input.title }),
          ...(input.description && { description: input.description }),
          ...(input.objectives && { objectives: input.objectives }),
          ...(input.status && { status: input.status as any }),
          ...(input.startDate && { startDate: new Date(input.startDate) }),
          ...(input.endDate && { endDate: new Date(input.endDate) }),
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'UPDATE_JOINT_INITIATIVE',
          entityType: 'JointInitiative',
          entityId: initiativeId,
          safeMetadata: input,
        },
      });

      return item;
    });

    return this.getInitiative(idirId, agreementId, updated.id);
  }

  async addInitiativeUpdate(
    idirId: string,
    agreementId: string,
    initiativeId: string,
    input: AddInitiativeUpdateInput,
    actorId: string
  ) {
    await this.assertParticipant(agreementId, idirId, true);

    const update = await prisma.initiativeUpdate.create({
      data: {
        initiativeId,
        content: input.content,
        createdById: actorId,
      },
    });

    return update;
  }

  async addInitiativeTask(
    idirId: string,
    agreementId: string,
    initiativeId: string,
    input: AddInitiativeTaskInput
  ) {
    await this.assertParticipant(agreementId, idirId, true);

    // Verify responsible Idir is a participant in this agreement
    await this.assertParticipant(agreementId, input.responsibleIdirId);

    const task = await prisma.initiativeTask.create({
      data: {
        initiativeId,
        title: input.title,
        description: input.description,
        responsibleIdirId: input.responsibleIdirId,
        dueDate: input.dueDate ? new Date(input.dueDate) : null,
      },
    });

    return task;
  }

  // ── 3. Cross-Idir Announcements ─────────────────────────────────────────────

  async listAnnouncements(idirId: string, agreementId: string) {
    await this.assertParticipant(agreementId, idirId);

    const announcements = await prisma.crossIdirAnnouncement.findMany({
      where: { agreementId },
      include: {
        publisherIdir: { select: { id: true, name: true } },
        createdBy: { select: { id: true, fullName: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return announcements.map((a) => ({
      id: a.id,
      agreementId: a.agreementId,
      publisherIdirName: a.publisherIdir.name,
      title: a.title,
      body: a.body,
      category: a.category,
      isWithdrawn: a.isWithdrawn,
      createdByName: a.createdBy.fullName,
      createdAt: a.createdAt,
    }));
  }

  async createAnnouncement(
    idirId: string,
    agreementId: string,
    input: CreateCrossAnnouncementInput,
    actorId: string
  ) {
    const agreement = await this.assertParticipant(agreementId, idirId, true);

    const announcement = await prisma.$transaction(async (tx) => {
      const created = await tx.crossIdirAnnouncement.create({
        data: {
          agreementId,
          publisherIdirId: idirId,
          title: input.title,
          body: input.body,
          category: (input.category as any) || 'GENERAL',
          createdById: actorId,
        },
        include: {
          publisherIdir: { select: { id: true, name: true } },
          createdBy: { select: { id: true, fullName: true } },
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'CREATE_CROSS_ANNOUNCEMENT',
          entityType: 'CrossIdirAnnouncement',
          entityId: created.id,
          safeMetadata: { title: input.title, category: input.category },
        },
      });

      return created;
    });

    // Notify all active members across all participating Idirs
    try {
      const participantIdirIds = [agreement.idirAId, agreement.idirBId];
      const activeMembers = await prisma.membership.findMany({
        where: {
          idirId: { in: participantIdirIds },
          status: 'ACTIVE',
        },
        select: { userId: true, idirId: true },
      });

      if (activeMembers.length > 0) {
        await prisma.notification.createMany({
          data: activeMembers.map((m) => ({
            userId: m.userId,
            title: `[Joint Announcement] ${input.title}`,
            body: input.body.slice(0, 150),
            type: 'ANNOUNCEMENT',
            data: { idirId: m.idirId, agreementId, announcementId: announcement.id },
          })),
        });
      }
    } catch (err) {
      logger.error({ err }, 'Failed to dispatch cross-Idir announcement notifications');
    }

    return {
      id: announcement.id,
      agreementId: announcement.agreementId,
      publisherIdirName: announcement.publisherIdir.name,
      title: announcement.title,
      body: announcement.body,
      category: announcement.category,
      isWithdrawn: announcement.isWithdrawn,
      createdByName: announcement.createdBy.fullName,
      createdAt: announcement.createdAt,
    };
  }

  async updateAnnouncement(
    idirId: string,
    agreementId: string,
    announcementId: string,
    input: UpdateCrossAnnouncementInput,
    actorId: string
  ) {
    await this.assertParticipant(agreementId, idirId, true);

    const announcement = await prisma.crossIdirAnnouncement.findFirst({
      where: { id: announcementId, agreementId },
    });

    if (!announcement) {
      throw new NotFoundError('Cross-Idir announcement not found');
    }

    if (announcement.publisherIdirId !== idirId) {
      throw new ForbiddenError('Only the publishing Idir can edit this announcement');
    }

    const updated = await prisma.$transaction(async (tx) => {
      const item = await tx.crossIdirAnnouncement.update({
        where: { id: announcementId },
        data: {
          ...(input.title && { title: input.title }),
          ...(input.body && { body: input.body }),
          ...(input.category && { category: input.category as any }),
        },
        include: {
          publisherIdir: { select: { id: true, name: true } },
          createdBy: { select: { id: true, fullName: true } },
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'UPDATE_CROSS_ANNOUNCEMENT',
          entityType: 'CrossIdirAnnouncement',
          entityId: announcementId,
          safeMetadata: input,
        },
      });

      return item;
    });

    return updated;
  }

  async withdrawAnnouncement(idirId: string, agreementId: string, announcementId: string, actorId: string) {
    await this.assertParticipant(agreementId, idirId, true);

    const announcement = await prisma.crossIdirAnnouncement.findFirst({
      where: { id: announcementId, agreementId },
    });

    if (!announcement) {
      throw new NotFoundError('Cross-Idir announcement not found');
    }

    if (announcement.publisherIdirId !== idirId) {
      throw new ForbiddenError('Only the publishing Idir can withdraw this announcement');
    }

    await prisma.$transaction(async (tx) => {
      await tx.crossIdirAnnouncement.update({
        where: { id: announcementId },
        data: {
          isWithdrawn: true,
          withdrawnAt: new Date(),
          withdrawnById: actorId,
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'WITHDRAW_CROSS_ANNOUNCEMENT',
          entityType: 'CrossIdirAnnouncement',
          entityId: announcementId,
        },
      });
    });
  }

  // ── 4. Emergency Coordination ───────────────────────────────────────────────

  async listEmergencies(idirId: string, agreementId: string) {
    await this.assertParticipant(agreementId, idirId);

    const emergencies = await prisma.crossIdirEmergency.findMany({
      where: { agreementId },
      include: {
        requestingIdir: { select: { id: true, name: true } },
        responses: {
          include: {
            respondingIdir: { select: { id: true, name: true } },
            respondedBy: { select: { id: true, fullName: true } },
          },
          orderBy: { createdAt: 'asc' },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return emergencies.map((e) => this._formatEmergency(e));
  }

  async createEmergency(
    idirId: string,
    agreementId: string,
    input: CreateCrossEmergencyInput,
    actorId: string
  ) {
    const agreement = await this.assertParticipant(agreementId, idirId, true);

    const emergency = await prisma.$transaction(async (tx) => {
      const created = await tx.crossIdirEmergency.create({
        data: {
          agreementId,
          requestingIdirId: idirId,
          title: input.title,
          description: input.description,
          emergencyType: input.emergencyType,
          urgency: (input.urgency as any) || 'HIGH',
          status: CrossIdirEmergencyStatus.OPEN,
          createdById: actorId,
        },
        include: {
          requestingIdir: { select: { id: true, name: true } },
          responses: {
            include: {
              respondingIdir: { select: { id: true, name: true } },
              respondedBy: { select: { id: true, fullName: true } },
            },
          },
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'CREATE_CROSS_EMERGENCY',
          entityType: 'CrossIdirEmergency',
          entityId: created.id,
          safeMetadata: {
            title: input.title,
            emergencyType: input.emergencyType,
            urgency: input.urgency,
          },
        },
      });

      return created;
    });

    // Notify partner Idirs' leaders
    try {
      const partnerIdirId = agreement.idirAId === idirId ? agreement.idirBId : agreement.idirAId;
      const partnerLeaders = await prisma.membership.findMany({
        where: {
          idirId: partnerIdirId,
          role: { in: ['CHAIRPERSON', 'CREATOR', 'OFFICER', 'SECRETARY', 'TREASURER'] as any },
          status: 'ACTIVE',
        },
        select: { userId: true },
      });

      if (partnerLeaders.length > 0) {
        await prisma.notification.createMany({
          data: partnerLeaders.map((l) => ({
            userId: l.userId,
            title: `[EMERGENCY ALERT] ${input.title}`,
            body: `Urgent assistance requested by ${emergency.requestingIdir.name}. Type: ${input.emergencyType}`,
            type: 'ANNOUNCEMENT',
            data: { idirId: partnerIdirId, agreementId, emergencyId: emergency.id },
          })),
        });
      }
    } catch (err) {
      logger.error({ err }, 'Failed to dispatch emergency alert notifications');
    }

    return this._formatEmergency(emergency);
  }

  async respondToEmergency(
    idirId: string,
    agreementId: string,
    emergencyId: string,
    input: RespondCrossEmergencyInput,
    actorId: string
  ) {
    await this.assertParticipant(agreementId, idirId, true);

    const emergency = await prisma.crossIdirEmergency.findFirst({
      where: { id: emergencyId, agreementId },
    });

    if (!emergency) {
      throw new NotFoundError('Emergency request not found');
    }

    const response = await prisma.$transaction(async (tx) => {
      const created = await tx.emergencyResponse.create({
        data: {
          emergencyId,
          respondingIdirId: idirId,
          message: input.message,
          commitmentNote: input.commitmentNote,
          respondedById: actorId,
        },
        include: {
          respondingIdir: { select: { id: true, name: true } },
          respondedBy: { select: { id: true, fullName: true } },
        },
      });

      // Update emergency status to ACKNOWLEDGED or IN_PROGRESS if open
      if (emergency.status === CrossIdirEmergencyStatus.OPEN) {
        await tx.crossIdirEmergency.update({
          where: { id: emergencyId },
          data: { status: CrossIdirEmergencyStatus.ACKNOWLEDGED },
        });
      }

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'RESPOND_CROSS_EMERGENCY',
          entityType: 'CrossIdirEmergency',
          entityId: emergencyId,
          safeMetadata: { commitmentNote: input.commitmentNote },
        },
      });

      return created;
    });

    return response;
  }

  async closeEmergency(
    idirId: string,
    agreementId: string,
    emergencyId: string,
    input: CloseCrossEmergencyInput,
    actorId: string
  ) {
    await this.assertParticipant(agreementId, idirId, true);

    const emergency = await prisma.crossIdirEmergency.findFirst({
      where: { id: emergencyId, agreementId },
    });

    if (!emergency) {
      throw new NotFoundError('Emergency request not found');
    }

    await prisma.$transaction(async (tx) => {
      await tx.crossIdirEmergency.update({
        where: { id: emergencyId },
        data: {
          status: CrossIdirEmergencyStatus.CLOSED,
          outcomeSummary: input.outcomeSummary,
          closedAt: new Date(),
          closedById: actorId,
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'CLOSE_CROSS_EMERGENCY',
          entityType: 'CrossIdirEmergency',
          entityId: emergencyId,
          safeMetadata: { outcomeSummary: input.outcomeSummary },
        },
      });
    });
  }

  // ── 5. Optional Joint Financial Support ─────────────────────────────────────

  async listCommitments(idirId: string, agreementId: string) {
    await this.assertParticipant(agreementId, idirId);

    const commitments = await prisma.jointFinancialCommitment.findMany({
      where: { agreementId },
      include: {
        contributingIdir: { select: { id: true, name: true } },
        authorizedBy: { select: { id: true, fullName: true } },
        confirmedBy: { select: { id: true, fullName: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return commitments.map((c) => this._formatCommitment(c));
  }

  async createCommitment(
    idirId: string,
    agreementId: string,
    input: CreateFinancialCommitmentInput,
    actorId: string
  ) {
    await this.assertParticipant(agreementId, idirId, true);

    if (input.initiativeId) {
      const initiative = await prisma.jointInitiative.findFirst({
        where: { id: input.initiativeId, agreementId },
      });
      if (!initiative) {
        throw new NotFoundError('Referenced joint initiative not found');
      }
    }

    const commitment = await prisma.$transaction(async (tx) => {
      const created = await tx.jointFinancialCommitment.create({
        data: {
          agreementId,
          initiativeId: input.initiativeId,
          contributingIdirId: idirId,
          amountCommitted: input.amountCommitted,
          currency: 'ETB',
          purpose: input.purpose,
          status: JointFinancialCommitmentStatus.PENDING,
          createdById: actorId,
        },
        include: {
          contributingIdir: { select: { id: true, name: true } },
          authorizedBy: { select: { id: true, fullName: true } },
          confirmedBy: { select: { id: true, fullName: true } },
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'CREATE_FINANCIAL_COMMITMENT',
          entityType: 'JointFinancialCommitment',
          entityId: created.id,
          safeMetadata: {
            amountCommitted: input.amountCommitted,
            purpose: input.purpose,
          },
        },
      });

      return created;
    });

    return this._formatCommitment(commitment);
  }

  async authorizeCommitment(idirId: string, agreementId: string, commitmentId: string, actorId: string) {
    await this.assertParticipant(agreementId, idirId, true);

    const commitment = await prisma.jointFinancialCommitment.findFirst({
      where: { id: commitmentId, agreementId },
    });

    if (!commitment) {
      throw new NotFoundError('Financial commitment not found');
    }

    if (commitment.contributingIdirId !== idirId) {
      throw new ForbiddenError('Only the contributing Idir can authorize its own financial commitment');
    }

    if (commitment.status !== JointFinancialCommitmentStatus.PENDING) {
      throw new AppError(
        `Commitment cannot be authorized from status ${commitment.status}`,
        400,
        'INVALID_STATUS'
      );
    }

    await prisma.$transaction(async (tx) => {
      await tx.jointFinancialCommitment.update({
        where: { id: commitmentId },
        data: {
          status: JointFinancialCommitmentStatus.AUTHORIZED,
          authorizedById: actorId,
          authorizedAt: new Date(),
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'AUTHORIZE_FINANCIAL_COMMITMENT',
          entityType: 'JointFinancialCommitment',
          entityId: commitmentId,
        },
      });
    });
  }

  async confirmCommitment(
    idirId: string,
    agreementId: string,
    commitmentId: string,
    input: ConfirmFinancialCommitmentInput,
    actorId: string
  ) {
    await this.assertParticipant(agreementId, idirId, true);

    const commitment = await prisma.jointFinancialCommitment.findFirst({
      where: { id: commitmentId, agreementId },
    });

    if (!commitment) {
      throw new NotFoundError('Financial commitment not found');
    }

    if (commitment.status === JointFinancialCommitmentStatus.CONFIRMED) {
      throw new AppError('This financial commitment is already confirmed', 400, 'ALREADY_CONFIRMED');
    }

    // Require authorization before confirmation
    if (commitment.status !== JointFinancialCommitmentStatus.AUTHORIZED) {
      throw new AppError(
        'Financial commitment must be authorized by contributing Idir before confirmation and reconciliation',
        400,
        'NOT_YET_AUTHORIZED'
      );
    }

    await prisma.$transaction(async (tx) => {
      // Link to existing financial architecture: Create an approved Expense in the contributing Idir!
      const expense = await tx.expense.create({
        data: {
          idirId: commitment.contributingIdirId,
          category: 'COMMUNITY' as any,
          amount: new Prisma.Decimal(input.amountConfirmed),
          currency: commitment.currency,
          expenseDate: new Date(),
          description: `[Cross-Idir Cooperation] ${commitment.purpose}`,
          status: 'APPROVED',
          recordedById: actorId,
          approvedById: actorId,
          approvedAt: new Date(),
        },
      });

      await tx.jointFinancialCommitment.update({
        where: { id: commitmentId },
        data: {
          status: JointFinancialCommitmentStatus.CONFIRMED,
          amountConfirmed: input.amountConfirmed,
          confirmedById: actorId,
          confirmedAt: new Date(),
          reconciliationNote: input.reconciliationNote,
          expenseId: expense.id,
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: 'CONFIRM_FINANCIAL_COMMITMENT',
          entityType: 'JointFinancialCommitment',
          entityId: commitmentId,
          safeMetadata: {
            amountConfirmed: input.amountConfirmed,
            reconciliationNote: input.reconciliationNote,
            linkedExpenseId: expense.id,
          },
        },
      });
    });
  }

  // ── Formatters ─────────────────────────────────────────────────────────────

  private _formatAgreement(a: any) {
    return {
      id: a.id,
      idirAId: a.idirAId,
      idirBId: a.idirBId,
      idirAName: a.idirA?.name ?? '',
      idirBName: a.idirB?.name ?? '',
      purpose: a.purpose,
      description: a.description,
      status: a.status,
      proposedDuration: a.proposedDuration,
      startDate: a.startDate,
      endDate: a.endDate,
      endReason: a.endReason,
      createdAt: a.createdAt,
      participants: (a.participants ?? []).map((p: any) => ({
        id: p.id,
        agreementId: p.agreementId,
        idirId: p.idirId,
        idirName: p.idir?.name ?? '',
        status: p.status,
        authorizedByUserName: p.authorizedBy?.fullName,
        authorizedAt: p.authorizedAt,
        rejectionReason: p.rejectionReason,
      })),
    };
  }

  private _formatInitiative(i: any) {
    return {
      id: i.id,
      agreementId: i.agreementId,
      title: i.title,
      description: i.description,
      objectives: i.objectives,
      category: i.category,
      status: i.status,
      ownerIdirId: i.ownerIdirId,
      ownerIdirName: i.ownerIdir?.name ?? '',
      startDate: i.startDate,
      endDate: i.endDate,
      createdAt: i.createdAt,
      updates: (i.updates ?? []).map((u: any) => ({
        id: u.id,
        content: u.content,
        postedByName: u.createdBy?.fullName ?? '',
        createdAt: u.createdAt,
      })),
      tasks: (i.tasks ?? []).map((t: any) => ({
        id: t.id,
        title: t.title,
        description: t.description,
        responsibleIdirId: t.responsibleIdirId,
        responsibleIdirName: t.responsibleIdir?.name ?? '',
        dueDate: t.dueDate,
        isCompleted: t.isCompleted,
        completedAt: t.completedAt,
      })),
    };
  }

  private _formatEmergency(e: any) {
    return {
      id: e.id,
      agreementId: e.agreementId,
      requestingIdirName: e.requestingIdir?.name ?? '',
      title: e.title,
      description: e.description,
      emergencyType: e.emergencyType,
      urgency: e.urgency,
      status: e.status,
      outcomeSummary: e.outcomeSummary,
      createdAt: e.createdAt,
      responses: (e.responses ?? []).map((r: any) => ({
        id: r.id,
        respondingIdirName: r.respondingIdir?.name ?? '',
        message: r.message,
        commitmentNote: r.commitmentNote,
        respondedByName: r.respondedBy?.fullName ?? '',
        createdAt: r.createdAt,
      })),
    };
  }

  private _formatCommitment(c: any) {
    return {
      id: c.id,
      contributingIdirName: c.contributingIdir?.name ?? '',
      amountCommitted: Number(c.amountCommitted),
      amountConfirmed: Number(c.amountConfirmed),
      currency: c.currency,
      purpose: c.purpose,
      status: c.status,
      authorizedByName: c.authorizedBy?.fullName,
      authorizedAt: c.authorizedAt,
      createdAt: c.createdAt,
    };
  }
}

export const cooperationService = new CooperationService();
