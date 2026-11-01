import { prisma } from '../../config/database.js';
import { NotFoundError, ForbiddenError, BadRequestError } from '../../shared/errors/AppError.js';
import {
  QueryChatMessagesInput,
  SendChatMessageInput,
  UpdateChatMessageInput,
  PinChatMessageInput,
  ReactChatMessageInput,
  UploadChatAttachmentInput,
  ReportChatMessageInput,
} from './chat.validation.js';

const messageSelect = {
  id: true,
  idirId: true,
  membershipId: true,
  senderId: true,
  senderName: true,
  senderRole: true,
  messageType: true,
  content: true,
  isEdited: true,
  replyToId: true,
  replyToSenderName: true,
  replyToContent: true,
  isForwarded: true,
  forwardedFromName: true,
  isPinned: true,
  pinnedAt: true,
  pinnedById: true,
  attachmentUrl: true,
  attachmentType: true,
  attachmentName: true,
  attachmentSize: true,
  attachmentDuration: true,
  reactions: true,
  mentions: true,
  clientMutationId: true,
  isDeleted: true,
  createdAt: true,
  updatedAt: true,
};

const LEADERSHIP_ROLES = [
  'CHAIRPERSON',
  'CREATOR',
  'SECRETARY',
  'TREASURER',
  'COMMITTEE',
  'AUDITOR',
  'OFFICER',
];

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
   * List paginated chat messages for an Idir with search and pin filters.
   */
  async listMessages(
    idirId: string,
    userId: string,
    query: QueryChatMessagesInput
  ) {
    await this.getActiveMembership(idirId, userId);

    const where: any = {
      idirId,
      isDeleted: false,
    };

    if (query.pinnedOnly) {
      where.isPinned = true;
    }

    if (query.before) {
      where.createdAt = { ...(where.createdAt || {}), lt: new Date(query.before) };
    }
    if (query.after) {
      where.createdAt = { ...(where.createdAt || {}), gt: new Date(query.after) };
    }

    if (query.search && query.search.trim().length > 0) {
      const searchTerm = query.search.trim();
      where.OR = [
        { content: { contains: searchTerm, mode: 'insensitive' } },
        { senderName: { contains: searchTerm, mode: 'insensitive' } },
        { attachmentName: { contains: searchTerm, mode: 'insensitive' } },
      ];
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
   * Send a new message (text, media, announcement, or reply) to the group chat.
   */
  async sendMessage(
    idirId: string,
    userId: string,
    input: SendChatMessageInput
  ) {
    const membership = await this.getActiveMembership(idirId, userId);

    // 1. Idempotency Check via clientMutationId to prevent duplicate sends on retries
    if (input.clientMutationId) {
      const existing = await prisma.chatMessage.findFirst({
        where: { idirId, clientMutationId: input.clientMutationId },
        select: messageSelect,
      });
      if (existing) {
        return existing;
      }
    }

    // 2. Role verification for official announcements & emergency broadcasts
    const isSpecialBroadcast =
      input.messageType === 'ANNOUNCEMENT' ||
      input.messageType === 'EMERGENCY' ||
      input.messageType === 'CONTRIBUTION_REMINDER';

    if (isSpecialBroadcast) {
      const isLeader = LEADERSHIP_ROLES.includes(membership.role.toUpperCase());
      if (!isLeader) {
        throw new ForbiddenError(
          'Insufficient permissions: Only Idir leaders and officers can broadcast official announcements or alerts.'
        );
      }
    }

    // 3. Persist the message
    const message = await prisma.chatMessage.create({
      data: {
        idirId,
        membershipId: membership.id,
        senderId: userId,
        senderName: membership.user.fullName,
        senderRole: membership.role,
        messageType: input.messageType || 'TEXT',
        content: input.content || '',
        replyToId: input.replyToId,
        replyToSenderName: input.replyToSenderName,
        replyToContent: input.replyToContent,
        isForwarded: input.isForwarded || false,
        forwardedFromName: input.forwardedFromName,
        attachmentUrl: input.attachmentUrl,
        attachmentType: input.attachmentType,
        attachmentName: input.attachmentName,
        attachmentSize: input.attachmentSize,
        attachmentDuration: input.attachmentDuration,
        clientMutationId: input.clientMutationId,
        mentions: input.mentions ? (input.mentions as any) : undefined,
        reactions: [],
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

    if (!existing || existing.idirId !== idirId || existing.isDeleted) {
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
   * Delete a message.
   * - Senders can delete their own message.
   * - Officers/Administrators can delete ANY message for group moderation.
   */
  async deleteMessage(
    idirId: string,
    userId: string,
    messageId: string
  ) {
    const membership = await this.getActiveMembership(idirId, userId);

    const existing = await prisma.chatMessage.findUnique({
      where: { id: messageId },
    });

    if (!existing || existing.idirId !== idirId || existing.isDeleted) {
      throw new NotFoundError('Message not found');
    }

    const isOwner = existing.senderId === userId;
    const isLeader = LEADERSHIP_ROLES.includes(membership.role.toUpperCase());

    if (!isOwner && !isLeader) {
      throw new ForbiddenError(
        'Access denied: You can only delete your own messages unless you are an Idir administrator.'
      );
    }

    // Soft delete to maintain auditability without displaying deleted content
    await prisma.chatMessage.update({
      where: { id: messageId },
      data: {
        isDeleted: true,
        content: '[Message deleted]',
        attachmentUrl: null,
      },
    });
  }

  /**
   * Pin or unpin a message. Restricted to Idir leadership.
   */
  async pinMessage(
    idirId: string,
    userId: string,
    messageId: string,
    input: PinChatMessageInput
  ) {
    const membership = await this.getActiveMembership(idirId, userId);
    const isLeader = LEADERSHIP_ROLES.includes(membership.role.toUpperCase());

    if (!isLeader) {
      throw new ForbiddenError(
        'Access denied: Only Idir leaders can pin or unpin messages in the community chat.'
      );
    }

    const existing = await prisma.chatMessage.findUnique({
      where: { id: messageId },
    });

    if (!existing || existing.idirId !== idirId || existing.isDeleted) {
      throw new NotFoundError('Message not found');
    }

    const updated = await prisma.chatMessage.update({
      where: { id: messageId },
      data: {
        isPinned: input.isPinned,
        pinnedAt: input.isPinned ? new Date() : null,
        pinnedById: input.isPinned ? userId : null,
      },
      select: messageSelect,
    });

    return updated;
  }

  /**
   * Add or remove an emoji reaction on a message.
   */
  async reactToMessage(
    idirId: string,
    userId: string,
    messageId: string,
    input: ReactChatMessageInput
  ) {
    const membership = await this.getActiveMembership(idirId, userId);

    const existing = await prisma.chatMessage.findUnique({
      where: { id: messageId },
    });

    if (!existing || existing.idirId !== idirId || existing.isDeleted) {
      throw new NotFoundError('Message not found');
    }

    let currentReactions: Array<{ emoji: string; userId: string; userName: string }> = [];
    if (Array.isArray(existing.reactions)) {
      currentReactions = existing.reactions as any;
    }

    let updatedReactions: Array<{ emoji: string; userId: string; userName: string }>;

    if (input.action === 'remove') {
      updatedReactions = currentReactions.filter(
        (r) => !(r.userId === userId && r.emoji === input.emoji)
      );
    } else {
      // Add reaction if not already present from this user
      const alreadyReacted = currentReactions.some(
        (r) => r.userId === userId && r.emoji === input.emoji
      );
      if (alreadyReacted) {
        updatedReactions = currentReactions;
      } else {
        updatedReactions = [
          ...currentReactions,
          {
            emoji: input.emoji,
            userId,
            userName: membership.user.fullName,
          },
        ];
      }
    }

    const updated = await prisma.chatMessage.update({
      where: { id: messageId },
      data: {
        reactions: updatedReactions as any,
      },
      select: messageSelect,
    });

    return updated;
  }

  /**
   * Server-side attachment upload validation and processing.
   */
  async uploadAttachment(
    idirId: string,
    userId: string,
    input: UploadChatAttachmentInput
  ) {
    await this.getActiveMembership(idirId, userId);

    const allowedMimeTypes = [
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
      'video/mp4',
      'video/quicktime',
      'audio/mpeg',
      'audio/mp4',
      'audio/aac',
      'audio/wav',
      'audio/ogg',
      'audio/m4a',
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ];

    const normalizedType = input.fileType.toLowerCase();
    const isAllowed = allowedMimeTypes.some((t) => normalizedType.includes(t.split('/')[1]));

    if (!isAllowed && !allowedMimeTypes.includes(normalizedType)) {
      throw new BadRequestError(
        `Unsupported file format: ${input.fileType}. Permitted formats include images, videos, audio/voice notes, and PDF documents.`
      );
    }

    // Determine category
    let attachmentType = 'DOCUMENT';
    if (normalizedType.startsWith('image/')) {
      attachmentType = 'IMAGE';
    } else if (normalizedType.startsWith('video/')) {
      attachmentType = 'VIDEO';
    } else if (normalizedType.startsWith('audio/')) {
      attachmentType = input.duration ? 'VOICE' : 'AUDIO';
    } else if (normalizedType.includes('pdf')) {
      attachmentType = 'PDF';
    }

    // Build data URI or storage URL
    const attachmentUrl = input.base64Data.startsWith('data:')
      ? input.base64Data
      : `data:${input.fileType};base64,${input.base64Data}`;

    return {
      attachmentUrl,
      attachmentType,
      attachmentName: input.fileName,
      attachmentSize: input.fileSize,
      attachmentDuration: input.duration || null,
    };
  }

  /**
   * Retrieve all pinned messages for the Idir.
   */
  async listPinnedMessages(idirId: string, userId: string) {
    await this.getActiveMembership(idirId, userId);

    const pinned = await prisma.chatMessage.findMany({
      where: {
        idirId,
        isPinned: true,
        isDeleted: false,
      },
      orderBy: { pinnedAt: 'desc' },
      select: messageSelect,
    });

    return pinned;
  }

  /**
   * Report an inappropriate message.
   */
  async reportMessage(
    idirId: string,
    userId: string,
    messageId: string,
    input: ReportChatMessageInput
  ) {
    const membership = await this.getActiveMembership(idirId, userId);

    const message = await prisma.chatMessage.findUnique({
      where: { id: messageId },
    });

    if (!message || message.idirId !== idirId) {
      throw new NotFoundError('Message not found');
    }

    // Log to AuditLog for officer review
    await prisma.auditLog.create({
      data: {
        idirId,
        actorId: userId,
        action: 'CHAT_MESSAGE_REPORTED',
        entityType: 'ChatMessage',
        entityId: messageId,
        ipAddress: '127.0.0.1',
        safeMetadata: {
          reporterName: membership.user.fullName,
          reportedSenderId: message.senderId,
          reportedSenderName: message.senderName,
          reason: input.reason,
          messageSnippet: message.content.substring(0, 100),
        },
      },
    });

    return { reported: true, messageId };
  }
}

export const chatService = new ChatService();
