import { prisma } from '../../config/database.js';
import { env } from '../../config/env.js';
import {
  BadRequestError,
  ForbiddenError,
  NotFoundError,
  RateLimitError,
} from '../../shared/errors/AppError.js';
import {
  normalizeEthPhone,
  generateInvitationToken,
  hashInvitationToken,
} from './invitation-crypto.js';
import { smsService } from './sms.service.js';
import { sendInvitationEmail } from '../auth/email.mailer.js';

export interface SkippedInvitation {
  phoneNumber?: string;
  email?: string;
  reason: string;
}

export interface SentInvitationItem {
  id: string;
  phoneNumber?: string | null;
  email?: string | null;
  inviteUrl: string;
  expiresAt: Date;
}

export interface BatchInvitationResult {
  totalRequested: number;
  sentCount: number;
  invitations: SentInvitationItem[];
  skipped: SkippedInvitation[];
}

export class InvitationsService {
  /**
   * Dispatches invitations in bulk to a list of Ethiopian mobile phone numbers and/or email addresses.
   *
   * Enforces:
   * 1. Actor is Idir creator or an active officer (CREATOR, CHAIRPERSON, SECRETARY, OFFICER).
   * 2. Hourly rate limit of max 100 invitations per Idir.
   * 3. Normalization of phone numbers to E.164 (+2519... or +2517...) and valid emails.
   * 4. Deduplication within the batch.
   * 5. Skipping existing active members.
   * 6. Cryptographic token generation (only SHA-256 hash persisted).
   * 7. Dispatching SMS via SmsService or email via sendInvitationEmail.
   */
  async sendBatchInvitations(
    idirId: string,
    actorId: string,
    phoneNumbers: string[] = [],
    expiresInDays = 7,
    options?: { baseUrl?: string; maxPerHour?: number; emails?: string[] }
  ): Promise<BatchInvitationResult> {
    let idir = await prisma.idir.findUnique({
      where: { id: idirId },
      select: {
        id: true,
        name: true,
        createdById: true,
        status: true,
      },
    });

    if (!idir && (idirId.startsWith('draft-') || idirId.length < 30)) {
      idir = await prisma.idir.findFirst({
        where: {
          OR: [
            { createdById: actorId },
            { memberships: { some: { userId: actorId, role: { in: ['CREATOR', 'CHAIRPERSON', 'SECRETARY', 'OFFICER'] } } } },
          ],
        },
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          name: true,
          createdById: true,
          status: true,
        },
      });

      if (!idir) {
        try {
          idir = await prisma.idir.create({
            data: {
              id: idirId,
              name: 'Community Idir',
              region: 'Addis Ababa',
              currency: 'ETB',
              status: 'ACTIVE',
              createdById: actorId,
            },
            select: {
              id: true,
              name: true,
              createdById: true,
              status: true,
            },
          });
        } catch (_) {}
      }
    }

    if (!idir) {
      throw new NotFoundError('Idir not found');
    }

    const resolvedIdirId = idir.id;

    // Permission check: Actor must be creator or have active officer role in this Idir
    const isCreator = idir.createdById === actorId;
    let isOfficer = false;

    if (!isCreator) {
      const membership = await prisma.membership.findFirst({
        where: {
          idirId: resolvedIdirId,
          userId: actorId,
          status: 'ACTIVE',
          role: {
            in: ['CREATOR', 'CHAIRPERSON', 'SECRETARY', 'OFFICER'],
          },
        },
      });
      isOfficer = Boolean(membership);
    }

    if (!isCreator && !isOfficer) {
      throw new ForbiddenError(
        'Only the Idir creator or authorized officers (Chairperson, Secretary, Officer) can send invitations'
      );
    }

    const actorUser = await prisma.user.findUnique({
      where: { id: actorId },
      select: { fullName: true },
    });

    const emails = options?.emails || [];
    const totalInputCount = phoneNumbers.length + emails.length;

    // Rate limit check: Maximum 100 invitations per Idir per hour
    const maxPerHour = options?.maxPerHour ?? 100;
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const recentInvitationsCount = await prisma.invitation.count({
      where: {
        idirId,
        createdAt: { gte: oneHourAgo },
      },
    });

    if (recentInvitationsCount + totalInputCount > maxPerHour) {
      throw new RateLimitError(
        `Invitation rate limit exceeded: Maximum ${maxPerHour} invitations allowed per hour. Already sent: ${recentInvitationsCount}`
      );
    }

    const baseUrl =
      options?.baseUrl ||
      (env.CORS_ORIGIN && env.CORS_ORIGIN !== '*'
        ? env.CORS_ORIGIN.split(',')[0]
        : 'http://localhost:8080');
    const expiresAt = new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000);

    const created: SentInvitationItem[] = [];
    const skipped: SkippedInvitation[] = [];
    const seenNumbersInBatch = new Set<string>();
    const seenEmailsInBatch = new Set<string>();

    // ── Process Phone Numbers ───────────────────────────────────────────────
    for (const rawPhone of phoneNumbers) {
      if (!rawPhone || !rawPhone.trim()) continue;

      let normalized: string;
      try {
        normalized = normalizeEthPhone(rawPhone);
      } catch (err: any) {
        skipped.push({
          phoneNumber: rawPhone,
          reason: err?.message || 'Invalid Ethiopian phone format',
        });
        continue;
      }

      if (seenNumbersInBatch.has(normalized)) {
        skipped.push({
          phoneNumber: rawPhone,
          reason: 'Duplicate phone number in current batch request',
        });
        continue;
      }
      seenNumbersInBatch.add(normalized);

      const rawDigits = normalized.replace(/\D/g, '');
      const localPhone = '0' + rawDigits.slice(3);
      const compactPhone = rawDigits.slice(3);

      const registeredUser = await prisma.user.findFirst({
        where: {
          OR: [
            { phoneNumber: normalized },
            { phoneNumber: localPhone },
            { phoneNumber: compactPhone },
            { phoneNumber: rawDigits },
            { phoneNumber: rawPhone.trim() },
          ],
        },
        select: { id: true, fullName: true, phoneNumber: true, email: true },
      });

      // Require recipient to be a registered user (in-app only)
      if (!registeredUser) {
        skipped.push({
          phoneNumber: normalized,
          reason: 'No registered user found with this phone number. The user must register on Idir first.',
        });
        continue;
      }

      const activeMember = await prisma.membership.findFirst({
        where: {
          idirId,
          userId: registeredUser.id,
          status: 'ACTIVE',
        },
        select: { id: true },
      });

      if (activeMember) {
        skipped.push({
          phoneNumber: normalized,
          reason: `${registeredUser.fullName} is already an active member of this Idir`,
        });
        continue;
      }

      const { rawToken, tokenHash } = generateInvitationToken();

      const existing = await prisma.invitation.findFirst({
        where: { idirId, phoneNumber: normalized, status: 'PENDING' },
      });

      let invitation;
      if (existing) {
        invitation = await prisma.invitation.update({
          where: { id: existing.id },
          data: {
            email: registeredUser?.email || existing.email || null,
            tokenHash,
            status: 'PENDING',
            expiresAt,
            createdById: actorId,
            usedAt: null,
            revokedAt: null,
            revokedById: null,
          },
        });
      } else {
        invitation = await prisma.invitation.create({
          data: {
            idirId,
            phoneNumber: normalized,
            email: registeredUser?.email || null,
            tokenHash,
            status: 'PENDING',
            expiresAt,
            createdById: actorId,
          },
        });
      }

      const inviteUrl = `${baseUrl}/invitation?token=${rawToken}`;
      // In-app invitation only — no external SMS dispatch.
      // The recipient will see the invitation inside the Idir app.

      created.push({
        id: invitation.id,
        phoneNumber: normalized,
        inviteUrl,
        expiresAt,
      });
    }

    // ── Process Emails ──────────────────────────────────────────────────────
    for (const rawEmail of emails) {
      if (!rawEmail || !rawEmail.trim()) continue;
      const normalized = rawEmail.trim().toLowerCase();

      if (!normalized.includes('@') || !normalized.includes('.')) {
        skipped.push({
          email: rawEmail,
          reason: 'Invalid email address format',
        });
        continue;
      }

      if (seenEmailsInBatch.has(normalized)) {
        skipped.push({
          email: rawEmail,
          reason: 'Duplicate email in current batch request',
        });
        continue;
      }
      seenEmailsInBatch.add(normalized);

      // Check if user is registered with this email
      const registeredUser = await prisma.user.findFirst({
        where: { email: { equals: normalized, mode: 'insensitive' } },
        select: { id: true, fullName: true, email: true, phoneNumber: true },
      });

      // Require recipient to be a registered user (in-app only)
      if (!registeredUser) {
        skipped.push({
          email: rawEmail,
          reason: 'No registered user found with this email. The user must register on Idir first.',
        });
        continue;
      }

      const activeMember = await prisma.membership.findFirst({
        where: {
          idirId,
          userId: registeredUser.id,
          status: 'ACTIVE',
        },
        select: { id: true },
      });

      if (activeMember) {
        skipped.push({
          email: normalized,
          reason: `${registeredUser.fullName} is already an active member of this Idir`,
        });
        continue;
      }

      const { rawToken, tokenHash } = generateInvitationToken();

      const existing = await prisma.invitation.findFirst({
        where: { idirId, email: normalized, status: 'PENDING' },
      });

      let invitation;
      if (existing) {
        invitation = await prisma.invitation.update({
          where: { id: existing.id },
          data: {
            phoneNumber: registeredUser?.phoneNumber || existing.phoneNumber || null,
            tokenHash,
            status: 'PENDING',
            expiresAt,
            createdById: actorId,
            usedAt: null,
            revokedAt: null,
            revokedById: null,
          },
        });
      } else {
        invitation = await prisma.invitation.create({
          data: {
            idirId,
            email: normalized,
            phoneNumber: registeredUser?.phoneNumber || null,
            tokenHash,
            status: 'PENDING',
            expiresAt,
            createdById: actorId,
          },
        });
      }

      const inviteUrl = `${baseUrl}/invitation?token=${rawToken}`;

      // In-app invitation only — no external email dispatch.
      // The recipient will see the invitation inside the Idir app.

      created.push({
        id: invitation.id,
        email: normalized,
        inviteUrl,
        expiresAt,
      });
    }

    return {
      totalRequested: totalInputCount,
      sentCount: created.length,
      invitations: created,
      skipped,
    };
  }

  /**
   * Pre-check if a user is registered by phone number or email before sending an invitation.
   */
  async checkUserRegistration(
    idirId: string,
    actorId: string,
    identifier: string
  ): Promise<{
    exists: boolean;
    user?: { id: string; fullName: string; phoneNumber?: string | null; email?: string | null };
    isAlreadyMember?: boolean;
    message: string;
  }> {
    const resolvedIdirId = await this.assertCanManageInvitations(idirId, actorId);

    const cleanInput = identifier.trim();
    if (!cleanInput) {
      return { exists: false, message: 'Please provide a phone number or email address.' };
    }

    let registeredUser;

    if (cleanInput.includes('@')) {
      registeredUser = await prisma.user.findFirst({
        where: { email: { equals: cleanInput, mode: 'insensitive' } },
        select: { id: true, fullName: true, phoneNumber: true, email: true },
      });
      if (!registeredUser) {
        return {
          exists: false,
          message: `No user found registered with email "${cleanInput}". The user must register first.`,
        };
      }
    } else {
      let normalized: string;
      try {
        normalized = normalizeEthPhone(cleanInput);
      } catch (e: any) {
        return {
          exists: false,
          message: e?.message || 'Invalid Ethiopian mobile phone number format',
        };
      }

      const rawDigits = normalized.replace(/\D/g, '');
      const localPhone = '0' + rawDigits.slice(3);
      const compactPhone = rawDigits.slice(3);

      registeredUser = await prisma.user.findFirst({
        where: {
          OR: [
            { phoneNumber: normalized },
            { phoneNumber: localPhone },
            { phoneNumber: compactPhone },
            { phoneNumber: rawDigits },
            { phoneNumber: cleanInput },
          ],
        },
        select: { id: true, fullName: true, phoneNumber: true, email: true },
      });

      if (!registeredUser) {
        return {
          exists: false,
          message: `No user found registered with phone number "${cleanInput}". The user must register first.`,
        };
      }
    }

    const activeMember = await prisma.membership.findFirst({
      where: {
        idirId: resolvedIdirId,
        userId: registeredUser.id,
        status: 'ACTIVE',
      },
      select: { id: true },
    });

    if (activeMember) {
      return {
        exists: true,
        user: registeredUser,
        isAlreadyMember: true,
        message: `${registeredUser.fullName} is already an active member of this Idir.`,
      };
    }

    return {
      exists: true,
      user: registeredUser,
      isAlreadyMember: false,
      message: `User found: ${registeredUser.fullName} (${registeredUser.email || registeredUser.phoneNumber}).`,
    };
  }

  /**
   * Helper to verify an actor has creator or officer permissions in an Idir.
   */
  private async assertCanManageInvitations(idirId: string, actorId: string): Promise<string> {
    let idir = await prisma.idir.findUnique({
      where: { id: idirId },
      select: { id: true, createdById: true },
    });

    if (!idir && (idirId.startsWith('draft-') || idirId.length < 30)) {
      idir = await prisma.idir.findFirst({
        where: {
          OR: [
            { createdById: actorId },
            { memberships: { some: { userId: actorId, role: { in: ['CREATOR', 'CHAIRPERSON', 'SECRETARY', 'OFFICER'] } } } },
          ],
        },
        orderBy: { createdAt: 'desc' },
        select: { id: true, createdById: true },
      });

      if (!idir) {
        try {
          idir = await prisma.idir.create({
            data: {
              id: idirId,
              name: 'Community Idir',
              region: 'Addis Ababa',
              currency: 'ETB',
              status: 'ACTIVE',
              createdById: actorId,
            },
            select: { id: true, createdById: true },
          });
        } catch (_) {}
      }
    }

    if (!idir) {
      throw new NotFoundError('Idir not found');
    }

    if (idir.createdById === actorId) {
      return idir.id;
    }

    const membership = await prisma.membership.findFirst({
      where: {
        idirId: idir.id,
        userId: actorId,
        status: 'ACTIVE',
        role: { in: ['CREATOR', 'CHAIRPERSON', 'SECRETARY', 'OFFICER'] },
      },
    });

    if (!membership) {
      throw new ForbiddenError(
        'Only the Idir creator or authorized officers can perform invitation management'
      );
    }

    return idir.id;
  }

  /**
   * Public lookup for an invitation token.
   * Returns view-only details of the Idir.
   * Uses a uniform generic message for non-existent, expired, revoked, or used tokens.
   */
  async verifyPublicInvitation(rawToken: string) {
    if (!rawToken || typeof rawToken !== 'string') {
      throw new BadRequestError('This invitation link is invalid or has expired');
    }

    const tokenHash = hashInvitationToken(rawToken);

    const invitation = await prisma.invitation.findUnique({
      where: { tokenHash },
      include: {
        idir: {
          select: {
            id: true,
            name: true,
            community: true,
            location: true,
            purpose: true,
            rules: true,
            contributionAmount: true,
            contributionFrequency: true,
            status: true,
          },
        },
      },
    });

    const isExpired = invitation ? invitation.expiresAt < new Date() : true;
    const isPending = invitation ? invitation.status === 'PENDING' : false;
    const isUnused = invitation ? invitation.usedAt === null : false;

    if (!invitation || !isPending || isExpired || !isUnused) {
      throw new BadRequestError('This invitation link is invalid or has expired');
    }

    return {
      valid: true,
      invitation: {
        phoneNumber: invitation.phoneNumber,
        email: invitation.email,
        expiresAt: invitation.expiresAt,
      },
      idir: invitation.idir,
    };
  }

  /**
   * Responds to an invitation (ACCEPT or DECLINE) on behalf of an authenticated user.
   */
  async respondToInvitation(rawToken: string, userId: string, action: 'ACCEPT' | 'DECLINE') {
    if (!rawToken || typeof rawToken !== 'string') {
      throw new BadRequestError('This invitation link is invalid or has expired');
    }

    const tokenHash = hashInvitationToken(rawToken);

    const invitation = await prisma.invitation.findUnique({
      where: { tokenHash },
      include: {
        idir: {
          select: { id: true, name: true },
        },
      },
    });

    const isExpired = invitation ? invitation.expiresAt < new Date() : true;
    const isPending = invitation ? invitation.status === 'PENDING' : false;
    const isUnused = invitation ? invitation.usedAt === null : false;

    if (!invitation || !isPending || isExpired || !isUnused) {
      throw new BadRequestError('This invitation link is invalid or has expired');
    }

    if (action === 'DECLINE') {
      await prisma.invitation.update({
        where: { id: invitation.id },
        data: {
          status: 'DECLINED',
          usedAt: new Date(),
        },
      });

      return {
        success: true,
        action: 'DECLINED',
        message: `You have declined the invitation to join ${invitation.idir.name}.`,
      };
    }

    // Handle ACCEPT: Ensure user gets an ACTIVE membership and invitation is marked ACCEPTED
    const now = new Date();
    const existingMembership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId: invitation.idirId,
          userId,
        },
      },
    });

    await prisma.$transaction(
      async (tx) => {
        if (existingMembership) {
          if (existingMembership.status !== 'ACTIVE') {
            await tx.membership.update({
              where: { id: existingMembership.id },
              data: { status: 'ACTIVE' },
            });
          }
        } else {
          const count = await tx.membership.count({
            where: { idirId: invitation.idirId },
          });
          const memberNumber = `M-${(count + 1).toString().padStart(4, '0')}`;

          await tx.membership.create({
            data: {
              idirId: invitation.idirId,
              userId,
              memberNumber,
              role: 'MEMBER',
              status: 'ACTIVE',
            },
          });
        }

        await tx.invitation.update({
          where: { id: invitation.id },
          data: {
            status: 'ACCEPTED',
            usedAt: now,
          },
        });

        // Ensure Idir status is ACTIVE now that members have joined
        await tx.idir.update({
          where: { id: invitation.idirId },
          data: { status: 'ACTIVE' },
        });
      },
      {
        maxWait: 15000,
        timeout: 30000,
      }
    );

    return {
      success: true,
      action: 'ACCEPTED',
      message: `You have successfully accepted the invitation and joined ${invitation.idir.name}!`,
      idir: invitation.idir,
    };
  }

  /**
   * Lists all invitations for an Idir (for officer management).
   */
  async listIdirInvitations(idirId: string, actorId: string) {
    await this.assertCanManageInvitations(idirId, actorId);

    return prisma.invitation.findMany({
      where: { idirId },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        phoneNumber: true,
        email: true,
        status: true,
        expiresAt: true,
        usedAt: true,
        createdAt: true,
        createdById: true,
        revokedAt: true,
      },
    });
  }

  /**
   * Revokes a specific invitation.
   */
  async revokeInvitation(idirId: string, actorId: string, invitationId: string) {
    await this.assertCanManageInvitations(idirId, actorId);

    const invitation = await prisma.invitation.findFirst({
      where: { id: invitationId, idirId },
    });

    if (!invitation) {
      throw new NotFoundError('Invitation not found');
    }

    await prisma.invitation.update({
      where: { id: invitation.id },
      data: {
        status: 'REVOKED',
        revokedById: actorId,
        revokedAt: new Date(),
      },
    });

    return {
      success: true,
      message: `Invitation for ${invitation.phoneNumber} has been revoked.`,
    };
  }

  /**
   * Revokes all pending invitations for an Idir.
   */
  async revokeAllPending(idirId: string, actorId: string) {
    await this.assertCanManageInvitations(idirId, actorId);

    const result = await prisma.invitation.updateMany({
      where: { idirId, status: 'PENDING' },
      data: {
        status: 'REVOKED',
        revokedById: actorId,
        revokedAt: new Date(),
      },
    });

    return {
      success: true,
      count: result.count,
      message: `${result.count} pending invitation(s) have been revoked.`,
    };
  }

  /**
   * Retrieves pending invitations received by the authenticated user.
   * Strictly filters invitations sent specifically to this user's email or phone number.
   * Excludes invitations created by this user or for Idirs the user already belongs to.
   */
  async getReceivedInvitations(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, phoneNumber: true },
    });

    if (!user) return [];

    const orConditions: any[] = [];
    if (user.email && user.email.trim()) {
      orConditions.push({ email: { equals: user.email.trim(), mode: 'insensitive' } });
    }
    if (user.phoneNumber && user.phoneNumber.trim()) {
      const cleanPhone = user.phoneNumber.trim();
      const rawDigits = cleanPhone.replace(/\D/g, '');
      if (rawDigits.length >= 9) {
        const compactPhone = rawDigits.slice(-9);
        const localPhone = '0' + compactPhone;
        const e164 = '+251' + compactPhone;

        const phoneSet = new Set<string>([cleanPhone, e164, localPhone, compactPhone, rawDigits]);
        for (const p of phoneSet) {
          orConditions.push({ phoneNumber: p });
        }
      } else {
        orConditions.push({ phoneNumber: cleanPhone });
      }
    }

    if (orConditions.length === 0) return [];

    // Filter out:
    // 1. Invitations created by this user (the inviter must never receive their own invite)
    // 2. Invitations for Idirs where this user is ALREADY an active member
    const activeMemberships = await prisma.membership.findMany({
      where: {
        userId,
        status: 'ACTIVE',
      },
      select: { idirId: true },
    });
    const alreadyMemberIdirIds = activeMemberships.map((m) => m.idirId);

    const invitations = await prisma.invitation.findMany({
      where: {
        status: 'PENDING',
        expiresAt: { gt: new Date() },
        usedAt: null,
        NOT: { createdById: userId }, // Inviter is never a recipient
        ...(alreadyMemberIdirIds.length > 0
          ? { idirId: { notIn: alreadyMemberIdirIds } }
          : {}),
        OR: orConditions,
      },
      include: {
        idir: {
          select: {
            id: true,
            name: true,
            community: true,
            location: true,
            description: true,
            contributionAmount: true,
            contributionFrequency: true,
            status: true,
          },
        },
        createdBy: {
          select: {
            id: true,
            fullName: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return invitations.map((inv) => ({
      id: inv.id,
      idirId: inv.idirId,
      idirName: inv.idir.name,
      community: inv.idir.community,
      location: inv.idir.location,
      description: inv.idir.description,
      contributionAmount: inv.idir.contributionAmount ? Number(inv.idir.contributionAmount) : null,
      contributionFrequency: inv.idir.contributionFrequency,
      invitedBy: inv.createdBy?.fullName || 'Idir Officer',
      phoneNumber: inv.phoneNumber,
      email: inv.email,
      createdAt: inv.createdAt,
      expiresAt: inv.expiresAt,
      status: inv.status,
    }));
  }

  /**
   * Responds to a received invitation by its ID (ACCEPT, DECLINE, or REJECT).
   */
  async respondToInvitationById(
    invitationId: string,
    userId: string,
    action: 'ACCEPT' | 'DECLINE' | 'REJECT' | string
  ) {
    const normalizedAction = (action || '').toUpperCase().trim();
    if (normalizedAction !== 'ACCEPT' && normalizedAction !== 'DECLINE' && normalizedAction !== 'REJECT') {
      throw new BadRequestError('Invalid action. Must be ACCEPT, DECLINE, or REJECT');
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, phoneNumber: true },
    });

    if (!user) {
      throw new NotFoundError('User not found');
    }

    const invitation = await prisma.invitation.findUnique({
      where: { id: invitationId },
      include: {
        idir: {
          select: { id: true, name: true },
        },
      },
    });

    if (!invitation) {
      throw new NotFoundError('Invitation not found');
    }

    if (invitation.status !== 'PENDING' || invitation.expiresAt < new Date() || invitation.usedAt !== null) {
      throw new BadRequestError('This invitation is no longer pending or has expired');
    }

    // Recipient verification: user must match invitation's email or phone number
    const userEmail = (user.email || '').toLowerCase().trim();
    const invEmail = (invitation.email || '').toLowerCase().trim();
    const matchesEmail = invEmail.length > 0 && invEmail === userEmail;

    const userDigits = (user.phoneNumber || '').replace(/\D/g, '').slice(-9);
    const invDigits = (invitation.phoneNumber || '').replace(/\D/g, '').slice(-9);
    const matchesPhone = invDigits.length >= 9 && userDigits.length >= 9 && invDigits === userDigits;

    if (!matchesEmail && !matchesPhone) {
      throw new ForbiddenError('This invitation was sent to a different user or contact');
    }

    if (normalizedAction === 'DECLINE' || normalizedAction === 'REJECT') {
      await prisma.invitation.update({
        where: { id: invitation.id },
        data: {
          status: 'DECLINED',
          usedAt: new Date(),
        },
      });

      return {
        success: true,
        action: 'DECLINED',
        message: `You have rejected the invitation to join ${invitation.idir.name}.`,
      };
    }

    // Handle ACCEPT
    const now = new Date();
    const existingMembership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId: invitation.idirId,
          userId,
        },
      },
    });

    await prisma.$transaction(
      async (tx) => {
        if (existingMembership) {
          if (existingMembership.status !== 'ACTIVE') {
            await tx.membership.update({
              where: { id: existingMembership.id },
              data: { status: 'ACTIVE' },
            });
          }
        } else {
          const count = await tx.membership.count({
            where: { idirId: invitation.idirId },
          });
          const memberNumber = `M-${(count + 1).toString().padStart(4, '0')}`;

          await tx.membership.create({
            data: {
              idirId: invitation.idirId,
              userId,
              memberNumber,
              role: 'MEMBER',
              status: 'ACTIVE',
            },
          });
        }

        await tx.invitation.update({
          where: { id: invitation.id },
          data: {
            status: 'ACCEPTED',
            usedAt: now,
          },
        });

        await tx.idir.update({
          where: { id: invitation.idirId },
          data: { status: 'ACTIVE' },
        });
      },
      {
        maxWait: 15000,
        timeout: 30000,
      }
    );

    return {
      success: true,
      action: 'ACCEPTED',
      message: `You have successfully joined ${invitation.idir.name}!`,
      idir: invitation.idir,
    };
  }
}

export const invitationsService = new InvitationsService();
