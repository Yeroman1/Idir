import { prisma } from '../../config/database.js';
import { NotFoundError } from '../../shared/errors/AppError.js';
import { reliableNotificationDispatcher } from '../notifications/reliable-dispatcher.service.js';
import { NotificationType } from '@prisma/client';
import {
  CreateMeetingInput,
  UpdateMeetingInput,
  RecordAttendanceInput,
} from './meetings.validation.js';

export class MeetingsService {
  async createMeeting(idirId: string, input: CreateMeetingInput, actorId: string) {
    const meeting = await prisma.meeting.create({
      data: {
        idirId,
        title: input.title,
        agenda: input.agenda,
        location: input.location,
        scheduledAt: new Date(input.scheduledAt),
        createdById: actorId,
        status: 'SCHEDULED',
      },
      include: {
        createdBy: { select: { id: true, fullName: true } },
      },
    });

    // Notify active members of this Idir about the new meeting
    try {
      const activeMembers = await prisma.membership.findMany({
        where: { idirId, status: 'ACTIVE' },
        select: { userId: true },
      });

      for (const member of activeMembers) {
        await reliableNotificationDispatcher.dispatch({
          userId: member.userId,
          title: `New Meeting: ${meeting.title}`,
          body: `A community meeting "${meeting.title}" is scheduled for ${meeting.scheduledAt.toLocaleDateString()}. Location: ${meeting.location || 'Idir Hall'}`,
          type: NotificationType.MEETING_REMINDER,
          data: { idirId, meetingId: meeting.id, scheduledAt: meeting.scheduledAt.toISOString() },
          idempotencyKey: `meeting-created-${meeting.id}-${member.userId}`,
        });
      }
    } catch {
      // Non-blocking notification dispatch
    }

    return meeting;
  }

  async listMeetings(idirId: string) {
    return prisma.meeting.findMany({
      where: { idirId },
      orderBy: { scheduledAt: 'desc' },
      include: {
        createdBy: { select: { id: true, fullName: true } },
        _count: { select: { attendances: true } },
      },
    });
  }

  async getMeetingById(idirId: string, meetingId: string) {
    const meeting = await prisma.meeting.findFirst({
      where: { id: meetingId, idirId },
      include: {
        createdBy: { select: { id: true, fullName: true } },
        attendances: {
          include: {
            membership: {
              include: { user: { select: { fullName: true, phoneNumber: true } } },
            },
          },
        },
      },
    });

    if (!meeting) {
      throw new NotFoundError('Meeting not found');
    }

    return meeting;
  }

  async updateMeeting(
    idirId: string,
    meetingId: string,
    input: UpdateMeetingInput
  ) {
    const meeting = await prisma.meeting.findFirst({
      where: { id: meetingId, idirId },
    });
    if (!meeting) {
      throw new NotFoundError('Meeting not found');
    }

    const updated = await prisma.meeting.update({
      where: { id: meetingId },
      data: {
        ...(input.title && { title: input.title }),
        ...(input.agenda !== undefined && { agenda: input.agenda }),
        ...(input.location !== undefined && { location: input.location }),
        ...(input.scheduledAt && { scheduledAt: new Date(input.scheduledAt) }),
        ...(input.status && { status: input.status }),
        ...(input.minutes !== undefined && { minutes: input.minutes }),
      },
    });

    if (input.scheduledAt || input.location || input.status) {
      try {
        const activeMembers = await prisma.membership.findMany({
          where: { idirId, status: 'ACTIVE' },
          select: { userId: true },
        });

        for (const member of activeMembers) {
          await reliableNotificationDispatcher.dispatch({
            userId: member.userId,
            title: `Meeting Update: ${updated.title}`,
            body: `Meeting "${updated.title}" status is now ${updated.status}. Scheduled: ${updated.scheduledAt.toLocaleDateString()}. Location: ${updated.location || 'Idir Hall'}`,
            type: NotificationType.MEETING_REMINDER,
            data: { idirId, meetingId: updated.id, status: updated.status },
            idempotencyKey: `meeting-update-${updated.id}-${updated.updatedAt.getTime()}-${member.userId}`,
          });
        }
      } catch {
        // Non-blocking
      }
    }

    return updated;
  }

  async recordAttendance(
    idirId: string,
    meetingId: string,
    input: RecordAttendanceInput
  ) {
    const meeting = await prisma.meeting.findFirst({
      where: { id: meetingId, idirId },
    });
    if (!meeting) {
      throw new NotFoundError('Meeting not found');
    }

    const membership = await prisma.membership.findFirst({
      where: { id: input.membershipId, idirId },
    });
    if (!membership) {
      throw new NotFoundError('Membership not found in this Idir');
    }

    return prisma.meetingAttendance.upsert({
      where: {
        meetingId_membershipId: {
          meetingId,
          membershipId: input.membershipId,
        },
      },
      update: {
        status: input.status,
        remarks: input.remarks,
        recordedAt: new Date(),
      },
      create: {
        meetingId,
        membershipId: input.membershipId,
        status: input.status,
        remarks: input.remarks,
      },
    });
  }
}

export const meetingsService = new MeetingsService();
