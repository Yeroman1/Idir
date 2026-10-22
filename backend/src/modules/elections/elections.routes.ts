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
import { resultsController } from './results.controller.js';
import {
  tallyVotesSchema,
  fileDisputeSchema,
  resolveDisputeSchema,
  certifyElectionSchema,
  triggerRunoffSchema,
} from './results.validation.js';
import { leadershipEventsController } from './leadership_events.controller.js';
import {
  initiateNoConfidenceSchema,
  castNoConfidenceVoteSchema,
  resolveNoConfidenceSchema,
  appointInterimSchema,
  createByElectionSchema,
} from './leadership_events.validation.js';

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

/* ==========================================================================
   COUNT, RESULTS & DISPUTES (Task 4)
   ========================================================================== */

// Tally votes (manual closure / trigger by committee/officers, or auto after voting window)
router.post(
  '/:electionId/tally',
  validate({ body: tallyVotesSchema }),
  resultsController.tallyVotes
);

// Get election results, quorum status, and dispute window
router.get(
  '/:electionId/results',
  resultsController.getResults
);

// File an election dispute during active dispute window
router.post(
  '/:electionId/disputes',
  validate({ body: fileDisputeSchema }),
  resultsController.fileDispute
);

// List all filed disputes
router.get(
  '/:electionId/disputes',
  resultsController.listDisputes
);

// Resolve or dismiss an election dispute (Committee or Chairperson)
router.post(
  '/:electionId/disputes/:disputeId/resolve',
  validate({ body: resolveDisputeSchema }),
  resultsController.resolveDispute
);

// Certify election results and transfer leadership roles
router.post(
  '/:electionId/certify',
  validate({ body: certifyElectionSchema }),
  resultsController.certifyElection
);

// Trigger run-off election for a role in case of a tie
router.post(
  '/:electionId/runoff',
  validate({ body: triggerRunoffSchema }),
  resultsController.triggerRunoff
);

/* ==========================================================================
   OTHER LEADERSHIP EVENTS & VACANCIES (Task 5)
   ========================================================================== */

// Inspect leadership vacancies across all institutional roles
router.get(
  '/vacancies/status',
  leadershipEventsController.getLeadershipVacancies
);

// Appoint an active member as interim temporary officer for a vacant role
router.post(
  '/vacancies/appoint',
  requireIdirRole([...ELECTION_MANAGERS]),
  validate({ body: appointInterimSchema }),
  leadershipEventsController.appointTemporaryOfficer
);

// Schedule an expedited by-election for a vacant leadership seat
router.post(
  '/vacancies/by-election',
  requireIdirRole([...ELECTION_MANAGERS]),
  validate({ body: createByElectionSchema }),
  leadershipEventsController.createByElection
);

// Initiate a vote of no-confidence against a sitting officer
router.post(
  '/no-confidence',
  validate({ body: initiateNoConfidenceSchema }),
  leadershipEventsController.initiateNoConfidence
);

// List all no-confidence votes in the Idir
router.get(
  '/no-confidence',
  leadershipEventsController.listNoConfidenceVotes
);

// Get single no-confidence vote details
router.get(
  '/no-confidence/:voteId',
  leadershipEventsController.getNoConfidenceVote
);

// Cast ballot in active no-confidence motion
router.post(
  '/no-confidence/:voteId/vote',
  validate({ body: castNoConfidenceVoteSchema }),
  leadershipEventsController.castNoConfidenceVote
);

// Resolve and conclude no-confidence vote (tally, quorum check, role removal)
router.post(
  '/no-confidence/:voteId/resolve',
  validate({ body: resolveNoConfidenceSchema }),
  leadershipEventsController.resolveNoConfidenceVote
);

export const electionRoutes = router;
