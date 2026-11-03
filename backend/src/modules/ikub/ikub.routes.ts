import { Router } from 'express';
import { ikubController } from './ikub.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import {
  createIkubGroupSchema,
  addParticipantSchema,
  createRoundSchema,
  drawLotterySchema,
  recordIkubContributionSchema,
  recordIkubPayoutSchema,
  queryIkubGroupsSchema,
  createJoinRequestSchema,
  respondJoinRequestSchema,
} from './ikub.validation.js';
import { requireActiveIdir } from '../../middleware/assertIdirActive.js';

const router = Router({ mergeParams: true });

router.use(authenticate);
router.use(requireActiveIdir());

// Active Ikub for the active Idir
router.get(
  '/active',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  ikubController.getActiveGroup
);

// Groups
router.post(
  '/groups',
  requireIdirRole(['CHAIRPERSON']), // Enforced: Chairperson creates the Ikub
  validate({ body: createIkubGroupSchema }),
  ikubController.createGroup
);

router.get(
  '/groups',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  validate({ query: queryIkubGroupsSchema }),
  ikubController.listGroups
);

router.get(
  '/groups/:groupId',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  ikubController.getGroupById
);

router.get(
  '/groups/:groupId/summary',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  ikubController.getGroupSummary
);

// Member Self-Join Request (Voluntary participation)
router.post(
  '/groups/:groupId/join',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  validate({ body: createJoinRequestSchema }),
  ikubController.requestToJoin
);

router.get(
  '/groups/:groupId/join-requests',
  requireIdirRole(['CHAIRPERSON', 'TREASURER', 'SECRETARY']),
  ikubController.listJoinRequests
);

router.post(
  '/groups/:groupId/join-requests/:requestId/respond',
  requireIdirRole(['CHAIRPERSON', 'TREASURER', 'SECRETARY']),
  validate({ body: respondJoinRequestSchema }),
  ikubController.respondToJoinRequest
);

// Participants (Direct Enrollment)
router.post(
  '/groups/:groupId/participants',
  requireIdirRole(['CHAIRPERSON', 'TREASURER', 'SECRETARY']),
  validate({ body: addParticipantSchema }),
  ikubController.addParticipant
);

// Rounds
router.post(
  '/groups/:groupId/rounds',
  requireIdirRole(['CHAIRPERSON', 'TREASURER']),
  validate({ body: createRoundSchema }),
  ikubController.createRound
);

// Lottery Draw (Automated or Manual Pick)
router.post(
  '/groups/:groupId/rounds/:roundId/draw',
  requireIdirRole(['CHAIRPERSON', 'TREASURER']),
  validate({ body: drawLotterySchema }),
  ikubController.drawLottery
);

// Contributions
router.post(
  '/groups/:groupId/contributions',
  requireIdirRole(['CHAIRPERSON', 'TREASURER']),
  validate({ body: recordIkubContributionSchema }),
  ikubController.recordContribution
);

// Payouts
router.post(
  '/groups/:groupId/payouts',
  requireIdirRole(['CHAIRPERSON', 'TREASURER']),
  validate({ body: recordIkubPayoutSchema }),
  ikubController.recordPayout
);

export const ikubRoutes = router;