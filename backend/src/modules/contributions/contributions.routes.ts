import { Router } from 'express';
import { contributionsController } from './contributions.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import {
  createContributionTypeSchema,
  recordContributionSchema,
  reverseContributionSchema,
  queryContributionsSchema,
} from './contributions.validation.js';
import { requireActiveIdir } from '../../middleware/assertIdirActive.js';

const router = Router({ mergeParams: true });

router.use(authenticate);
router.use(requireActiveIdir());

// Contribution types
router.post(
  '/types',
  requireIdirRole(['CHAIRPERSON', 'TREASURER']),
  validate({ body: createContributionTypeSchema }),
  contributionsController.createType
);

router.get(
  '/types',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  contributionsController.listTypes
);

// Contributions
router.post(
  '/',
  requireIdirRole(['CHAIRPERSON', 'TREASURER']),
  validate({ body: recordContributionSchema }),
  contributionsController.recordContribution
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
  validate({ query: queryContributionsSchema }),
  contributionsController.listContributions
);

// Member Dues Status (Expected, Paid, Partially Paid, Overdue)
router.get(
  '/dues-status',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  contributionsController.getDuesStatus
);

router.get(
  '/:contributionId',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  contributionsController.getContributionById
);

router.post(
  '/:contributionId/confirm',
  requireIdirRole(['CHAIRPERSON', 'TREASURER']),
  contributionsController.confirmContribution
);

router.post(
  '/:contributionId/reverse',
  requireIdirRole(['CHAIRPERSON', 'TREASURER']),
  validate({ body: reverseContributionSchema }),
  contributionsController.reverseContribution
);

export const contributionRoutes = router;
