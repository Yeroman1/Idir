import { prisma } from '../../config/database.js';
import { NotFoundError, ForbiddenError } from '../../shared/errors/AppError.js';
import { QueryChatMessagesInput, SendChatMessageInput } from './chat.validation.js';

export class ChatService {
  /**
   * Verify that the user has an active membership in the given Idir.
   */
  private async getActiveMembership(idirId: string, userId: string) {
    const membership = await prisma.membership.findUnique({
      where: {
        idirId_userId: {
          idirId,
          userId,
        },
      },
      include: {
        user: { select: { id: true, fullName: true } },
      },
    });

    if (!membership || membership.status !== 'ACTIVE') {
      throw new ForbiddenError(
        'Access denied: You must be an active member of this Idir to access the group chat.'
      );
    }

    return membership;
  }

  /**
   * List paginated chat messages for an Idir.
   */
  async listMessages(
    idirId: string,
    userId: string,
    query: QueryChatMessagesInput
  ) {
    // Assert membership
    await this.getActiveMembership(idirId, userId);

    const where: any = { idirId };
    if (query.before) {
      where.createdAt = { ...(where.createdAt || {}), lt: new Date(query.before) };
    }
    if (query.after) {
      where.createdAt = { ...(where.createdAt || {}), gt: new Date(query.after) };
    }

    const messages = await prisma.chatMessage.findMany({
      where,
      take: query.limit,
      orderBy: { createdAt: 'asc' },
      select: {
        id: true,
        idirId: true,
        membershipId: true,
        senderId: true,
        senderName: true,
        senderRole: true,
        content: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    return messages;
  }

  /**
   * Send a new message to the Idir group chat.
   */
  async sendMessage(
    idirId: string,
    userId: string,
    input: SendChatMessageInput
  ) {
    // Assert membership and get sender details
    const membership = await this.getActiveMembership(idirId, userId);

    const message = await prisma.chatMessage.create({
      data: {
        idirId,
        membershipId: membership.id,
        senderId: userId,
        senderName: membership.user.fullName,
        senderRole: membership.role,
        content: input.content,
      },
      select: {
        id: true,
        idirId: true,
        membershipId: true,
        senderId: true,
        senderName: true,
        senderRole: true,
        content: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    return message;
  }
}

export const chatService = new ChatService();
