import { Router } from 'express';
import { meetingsController } from './meetings.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import {
  createMeetingSchema,
  updateMeetingSchema,
  recordAttendanceSchema,
} from './meetings.validation.js';

const router = Router({ mergeParams: true });

router.use(authenticate);

router.post(
  '/',
  requireIdirRole(['CHAIRPERSON', 'SECRETARY']),
  validate({ body: createMeetingSchema }),
  meetingsController.createMeeting
);

router.get(
  '/',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  meetingsController.listMeetings
);

router.get(
  '/:meetingId',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  meetingsController.getMeetingById
);

router.patch(
  '/:meetingId',
  requireIdirRole(['CHAIRPERSON', 'SECRETARY']),
  validate({ body: updateMeetingSchema }),
  meetingsController.updateMeeting
);

router.post(
  '/:meetingId/attendance',
  requireIdirRole(['CHAIRPERSON', 'SECRETARY']),
  validate({ body: recordAttendanceSchema }),
  meetingsController.recordAttendance
);

export const meetingRoutes = router;
