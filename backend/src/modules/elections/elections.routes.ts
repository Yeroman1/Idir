import { Router } from 'express';
import { electionsController } from './elections.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';
import { requireActiveIdir } from '../../middleware/assertIdirActive.js';
import { validate } from '../../middleware/validate.js';
import {
  createElectionSchema,
  updateElectionSchema,
  queryElectionsSchema,
  cancelElectionSchema,
} from './elections.validation.js';
import { nominationsController } from './nominations.controller.js';
import {
  createNominationSchema,
  respondNominationSchema,
  updateStatementSchema,
  queryNominationsSchema,
} from './nominations.validation.js';
import { votingController } from './voting.controller.js';
import {
  castVoteSchema,
  castBatchVotesSchema,
} from './voting.validation.js';

const router = Router({ mergeParams: true });

// All election routes require authentication and an active Idir
router.use(authenticate);
router.use(requireActiveIdir());

// Allowed leadership officers for election management
const ELECTION_MANAGERS = [
  'CREATOR',
  'CHAIRPERSON',
  'OFFICER',
  'SECRETARY',
  'COMMITTEE',
] as const;

// Create election: only allowed officers
router.post(
  '/',
  requireIdirRole([...ELECTION_MANAGERS]),
  validate({ body: createElectionSchema }),
  electionsController.createElection
);

// List elections for this Idir: all active members can view
router.get(
  '/',
  validate({ query: queryElectionsSchema }),
  electionsController.listElections
);

// Get election details: all active members can view
router.get(
  '/:electionId',
  electionsController.getElection
);

// Update election settings (only allowed officers, while in DRAFT)
router.patch(
  '/:electionId',
  requireIdirRole([...ELECTION_MANAGERS]),
  validate({ body: updateElectionSchema }),
  electionsController.updateElection
);

// Cancel election: only allowed officers
router.post(
  '/:electionId/cancel',
  requireIdirRole([...ELECTION_MANAGERS]),
  validate({ body: cancelElectionSchema }),
  electionsController.cancelElection
);

/* ==========================================================================
   NOMINATIONS & CANDIDATES (Task 2)
   ========================================================================== */

// Nominate self or another active member
router.post(
  '/:electionId/nominations',
  validate({ body: createNominationSchema }),
  nominationsController.createNomination
);

// List nominations (by default only ACCEPTED candidates for the ballot)
router.get(
  '/:electionId/nominations',
  validate({ query: queryNominationsSchema }),
  nominationsController.listNominations
);

// View candidate page & details
router.get(
  '/:electionId/nominations/:nominationId',
  nominationsController.getCandidatePage
);

// Respond to nomination (accept or decline)
router.post(
  '/:electionId/nominations/:nominationId/respond',
  validate({ body: respondNominationSchema }),
  nominationsController.respondToNomination
);

// Withdraw candidacy
router.post(
  '/:electionId/nominations/:nominationId/withdraw',
  nominationsController.withdrawNomination
);

// Update candidate short statement
router.patch(
  '/:electionId/nominations/:nominationId/statement',
  validate({ body: updateStatementSchema }),
  nominationsController.updateStatement
);

/* ==========================================================================
   VOTING & BALLOTS (Task 3)
   ========================================================================== */

// Get ballot with accepted candidates per contested role
router.get(
  '/:electionId/ballot',
  votingController.getElectionBallot
);

// Get member voting status (voted roles, verification receipts)
router.get(
  '/:electionId/voting-status',
  votingController.getMemberVotingStatus
);

// Cast a vote for a role (Fayda verified, one vote per role)
router.post(
  '/:electionId/vote',
  validate({ body: castVoteSchema }),
  votingController.castVote
);

// Cast multiple votes in batch
router.post(
  '/:electionId/vote/batch',
  validate({ body: castBatchVotesSchema }),
  votingController.castBatchVotes
);

export const electionRoutes = router;
