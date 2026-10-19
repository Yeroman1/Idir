import { Response, NextFunction } from 'express';
import { meetingsService } from './meetings.service.js';
import { sendSuccess, sendCreated } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';

export class MeetingsController {
  async createMeeting(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const meeting = await meetingsService.createMeeting(
        req.params.idirId,
        req.body,
        req.user!.id
      );
      return sendCreated(res, meeting, 'Meeting scheduled successfully');
    } catch (error) {
      next(error);
    }
  }

  async listMeetings(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const meetings = await meetingsService.listMeetings(req.params.idirId);
      return sendSuccess(res, meetings);
    } catch (error) {
      next(error);
    }
  }

  async getMeetingById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const meeting = await meetingsService.getMeetingById(
        req.params.idirId,
        req.params.meetingId
      );
      return sendSuccess(res, meeting);
    } catch (error) {
      next(error);
    }
  }

  async updateMeeting(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const meeting = await meetingsService.updateMeeting(
        req.params.idirId,
        req.params.meetingId,
        req.body
      );
      return sendSuccess(res, meeting, 200, 'Meeting updated');
    } catch (error) {
      next(error);
    }
  }

  async recordAttendance(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const attendance = await meetingsService.recordAttendance(
        req.params.idirId,
        req.params.meetingId,
        req.body
      );
      return sendSuccess(res, attendance, 200, 'Attendance recorded');
    } catch (error) {
      next(error);
    }
  }
}

export const meetingsController = new MeetingsController();
