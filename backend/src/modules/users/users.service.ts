import { prisma } from '../../config/database.js';
import { NotFoundError, ConflictError, BadRequestError } from '../../shared/errors/AppError.js';
import { UpdateProfileInput } from './users.validation.js';

export class UsersService {
  async getProfile(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        fullName: true,
        phoneNumber: true,
        email: true,
        address: true,
        dateOfBirth: true,
        preferredLanguage: true,
        status: true,
        isPlatformAdmin: true,
        createdAt: true,
        updatedAt: true,
        memberships: {
          select: {
            id: true,
            idirId: true,
            role: true,
            status: true,
            memberNumber: true,
            idir: {
              select: {
                id: true,
                name: true,
                currency: true,
                status: true,
              },
            },
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundError('User not found');
    }

    return user;
  }

  async updateProfile(userId: string, input: UpdateProfileInput) {
    const existing = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        phoneNumber: true,
      },
    });

    if (!existing) {
      throw new NotFoundError('User not found');
    }

    // STRICT IMMUTABILITY: Email address cannot be changed under any circumstance
    if (input.email !== undefined && input.email !== null) {
      const inputEmailClean = input.email.trim().toLowerCase();
      const existingEmailClean = existing.email ? existing.email.trim().toLowerCase() : '';
      if (inputEmailClean !== existingEmailClean) {
        throw new BadRequestError('Email address cannot be changed. Your registered email is permanent.');
      }
    }

    // Phone number duplicate validation if phone number is being changed
    if (input.phoneNumber && input.phoneNumber !== existing.phoneNumber) {
      const existingPhone = await prisma.user.findFirst({
        where: { phoneNumber: input.phoneNumber.trim(), NOT: { id: userId } },
      });
      if (existingPhone) {
        throw new ConflictError('Phone number is already in use by another account');
      }
    }

    // Note: 'email' is intentionally excluded from the update payload
    const updated = await prisma.user.update({
      where: { id: userId },
      data: {
        ...(input.fullName !== undefined && { fullName: input.fullName.trim() }),
        ...(input.phoneNumber !== undefined && { phoneNumber: input.phoneNumber.trim() }),
        ...(input.address !== undefined && { address: input.address?.trim() || null }),
        ...(input.preferredLanguage !== undefined && {
          preferredLanguage: input.preferredLanguage,
        }),
        ...(input.dateOfBirth !== undefined && {
          dateOfBirth: input.dateOfBirth ? new Date(input.dateOfBirth) : null,
        }),
      },
      select: {
        id: true,
        fullName: true,
        phoneNumber: true,
        email: true,
        address: true,
        dateOfBirth: true,
        preferredLanguage: true,
        status: true,
        isPlatformAdmin: true,
        createdAt: true,
        updatedAt: true,
        memberships: {
          select: {
            id: true,
            idirId: true,
            role: true,
            status: true,
            memberNumber: true,
            idir: {
              select: {
                id: true,
                name: true,
                currency: true,
                status: true,
              },
            },
          },
        },
      },
    });

    return updated;
  }
}

export const usersService = new UsersService();
