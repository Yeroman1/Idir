import { prisma } from '../../config/database.js';
import { NotFoundError, ForbiddenError } from '../../shared/errors/AppError.js';
import { QueryChatMessagesInput, SendChatMessageInput, UpdateChatMessageInput } from './chat.validation.js';

const messageSelect = {
  id: true,
  idirId: true,
  membershipId: true,
  senderId: true,
  senderName: true,
  senderRole: true,
  content: true,
  isEdited: true,
  createdAt: true,
  updatedAt: true,
};

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
      select: messageSelect,
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
      select: messageSelect,
    });

    return message;
  }

  /**
   * Edit a message. Only the original sender may edit their own message.
   */
  async editMessage(
    idirId: string,
    userId: string,
    messageId: string,
    input: UpdateChatMessageInput
  ) {
    await this.getActiveMembership(idirId, userId);

    const existing = await prisma.chatMessage.findUnique({
      where: { id: messageId },
    });

    if (!existing || existing.idirId !== idirId) {
      throw new NotFoundError('Message not found');
    }

    if (existing.senderId !== userId) {
      throw new ForbiddenError('You can only edit your own messages');
    }

    const updated = await prisma.chatMessage.update({
      where: { id: messageId },
      data: {
        content: input.content,
        isEdited: true,
      },
      select: messageSelect,
    });

    return updated;
  }

  /**
   * Delete a message. Only the original sender may delete their own message.
   */
  async deleteMessage(
    idirId: string,
    userId: string,
    messageId: string
  ) {
    await this.getActiveMembership(idirId, userId);

    const existing = await prisma.chatMessage.findUnique({
      where: { id: messageId },
    });

    if (!existing || existing.idirId !== idirId) {
      throw new NotFoundError('Message not found');
    }

    if (existing.senderId !== userId) {
      throw new ForbiddenError('You can only delete your own messages');
    }

    await prisma.chatMessage.delete({
      where: { id: messageId },
    });
  }
}

export const chatService = new ChatService();
