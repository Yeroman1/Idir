import { prisma } from '../../config/database.js';
import { NotFoundError } from '../../shared/errors/AppError.js';
import {
  CreateMeetingInput,
  UpdateMeetingInput,
  RecordAttendanceInput,
} from './meetings.validation.js';

export class MeetingsService {
  async createMeeting(idirId: string, input: CreateMeetingInput, actorId: string) {
    return prisma.meeting.create({
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

    return prisma.meeting.update({
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
