import { Router } from 'express';
import { ikubController } from './ikub.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import {
  createIkubGroupSchema,
  addParticipantSchema,
  createRoundSchema,
  recordIkubContributionSchema,
  recordIkubPayoutSchema,
  queryIkubGroupsSchema,
} from './ikub.validation.js';

const router = Router({ mergeParams: true });

router.use(authenticate);

// Groups
router.post(
  '/groups',
  requireIdirRole(['CHAIRPERSON', 'TREASURER']),
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

// Participants
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
