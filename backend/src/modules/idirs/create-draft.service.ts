import { Prisma } from '@prisma/client';
import { prisma } from '../../config/database.js';
import { CreateDraftIdirInput } from './create-draft.validation.js';

export class CreateDraftIdirService {
  async createDraft(creatorUserId: string, input: CreateDraftIdirInput) {
    return prisma.$transaction(async (tx) => {
      // 1. Create Idir with status DRAFT
      // Status is forced to DRAFT regardless of any client-supplied value
      const idir = await tx.idir.create({
        data: {
          name: input.name.trim(),
          community: input.community.trim(),
          location: input.location.trim(),
          purpose: input.purpose.trim(),
          rules: input.rules ? input.rules.trim() : null,
          contributionAmount: new Prisma.Decimal(input.contributionAmount),
          contributionFrequency: input.contributionFrequency,
          status: 'ACTIVE',
          createdById: creatorUserId,
          currency: 'ETB',
        },
        include: {
          createdBy: {
            select: {
              id: true,
              fullName: true,
              phoneNumber: true,
              faydaId: true,
            },
          },
        },
      });

      // 2. Create Default Settings
      const duesFrequencyMap: Record<string, 'WEEKLY' | 'MONTHLY' | 'QUARTERLY' | 'ANNUALLY'> = {
        WEEKLY: 'WEEKLY',
        MONTHLY: 'MONTHLY',
        QUARTERLY: 'QUARTERLY',
        YEARLY: 'ANNUALLY',
      };

      await tx.idirSettings.create({
        data: {
          idirId: idir.id,
          regularDuesAmount: new Prisma.Decimal(input.contributionAmount),
          duesFrequency: duesFrequencyMap[input.contributionFrequency] ?? 'MONTHLY',
          latePaymentGraceDays: 15,
          meetingFrequency: 'MONTHLY',
          allowIkub: true,
          requireMultiApproval: true,
        },
      });

      // 3. Create Default Regular Contribution Type
      await tx.contributionType.create({
        data: {
          idirId: idir.id,
          name: 'Regular Dues',
          description: 'Standard membership contribution',
          defaultAmount: new Prisma.Decimal(input.contributionAmount),
          isMandatory: true,
          isActive: true,
        },
      });

      // 4. Assign creator as CHAIRPERSON membership
      const membership = await tx.membership.create({
        data: {
          idirId: idir.id,
          userId: creatorUserId,
          memberNumber: 'IDIR-001',
          role: 'CHAIRPERSON',
          status: 'ACTIVE',
        },
      });

      // 5. Audit Log
      await tx.auditLog.create({
        data: {
          actorId: creatorUserId,
          idirId: idir.id,
          action: 'CREATE_IDIR_DRAFT',
          entityType: 'Idir',
          entityId: idir.id,
          safeMetadata: { name: idir.name, status: 'DRAFT' },
        },
      });

      return {
        ...idir,
        membership,
      };
    }, {
      maxWait: 15000,
      timeout: 30000,
    });
  }
}

export const createDraftIdirService = new CreateDraftIdirService();
