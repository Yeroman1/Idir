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
    const idir = await prisma.idir.findUnique({
      where: { id: idirId },
      select: {
        id: true,
        name: true,
        createdById: true,
        status: true,
      },
    });

    if (!idir) {
      throw new NotFoundError('Idir not found');
    }

    // Permission check: Actor must be creator or have active officer role in this Idir
    const isCreator = idir.createdById === actorId;
    let isOfficer = false;

    if (!isCreator) {
      const membership = await prisma.membership.findFirst({
        where: {
          idirId,
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
        select: { id: true, fullName: true, phoneNumber: true },
      });

      if (!registeredUser) {
        skipped.push({
          phoneNumber: normalized,
          reason: 'No user found with this phone number. User must register first.',
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
            tokenHash,
            status: 'PENDING',
            expiresAt,
            createdById: actorId,
          },
        });
      }

      const inviteUrl = `${baseUrl}/invitation?token=${rawToken}`;
      await smsService.sendInvitationSms(normalized, idir.name, inviteUrl);

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
        select: { id: true, fullName: true, email: true },
      });

      if (registeredUser) {
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
            tokenHash,
            status: 'PENDING',
            expiresAt,
            createdById: actorId,
          },
        });
      }

      const inviteUrl = `${baseUrl}/invitation?token=${rawToken}`;

      // Dispatch invitation email using Gmail SMTP / Resend
      await sendInvitationEmail(normalized, idir.name, inviteUrl, actorUser?.fullName);

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
    await this.assertCanManageInvitations(idirId, actorId);

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
        idirId,
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
  private async assertCanManageInvitations(idirId: string, actorId: string): Promise<void> {
    const idir = await prisma.idir.findUnique({
      where: { id: idirId },
      select: { createdById: true },
    });

    if (!idir) {
      throw new NotFoundError('Idir not found');
    }

    if (idir.createdById === actorId) {
      return;
    }

    const membership = await prisma.membership.findFirst({
      where: {
        idirId,
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
}

export const invitationsService = new InvitationsService();
