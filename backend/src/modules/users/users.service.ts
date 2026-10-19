import { prisma } from '../../config/database.js';
import { NotFoundError, ConflictError } from '../../shared/errors/AppError.js';
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
        preferredLanguage: true,
        faydaId: true,
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
    if (input.email) {
      const existingEmail = await prisma.user.findFirst({
        where: { email: input.email, NOT: { id: userId } },
      });
      if (existingEmail) {
        throw new ConflictError('Email address is already in use by another account');
      }
    }

    if (input.faydaId) {
      const existingFayda = await prisma.user.findFirst({
        where: { faydaId: input.faydaId, NOT: { id: userId } },
      });
      if (existingFayda) {
        throw new ConflictError('Fayda ID is already linked to another account');
      }
    }

    const updated = await prisma.user.update({
      where: { id: userId },
      data: {
        ...(input.fullName !== undefined && { fullName: input.fullName }),
        ...(input.email !== undefined && { email: input.email }),
        ...(input.preferredLanguage !== undefined && {
          preferredLanguage: input.preferredLanguage,
        }),
        ...(input.faydaId !== undefined && { faydaId: input.faydaId }),
      },
      select: {
        id: true,
        fullName: true,
        phoneNumber: true,
        email: true,
        preferredLanguage: true,
        faydaId: true,
        status: true,
        isPlatformAdmin: true,
        updatedAt: true,
      },
    });

    return updated;
  }
}

export const usersService = new UsersService();
