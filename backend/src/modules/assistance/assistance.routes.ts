import { Router } from 'express';
import { assistanceController } from './assistance.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import {
  createCaseSchema,
  submitRequestSchema,
  reviewRequestSchema,
  disburseSchema,
  queryCasesSchema,
} from './assistance.validation.js';
import { requireActiveIdir } from '../../middleware/assertIdirActive.js';

const router = Router({ mergeParams: true });

router.use(authenticate);
router.use(requireActiveIdir());

// Cases
router.post(
  '/cases',
  requireIdirRole(['CHAIRPERSON', 'TREASURER', 'SECRETARY', 'COMMITTEE', 'MEMBER']),
  validate({ body: createCaseSchema }),
  assistanceController.createCase
);

router.get(
  '/cases',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  validate({ query: queryCasesSchema }),
  assistanceController.listCases
);

router.get(
  '/cases/:caseId',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  assistanceController.getCaseById
);

// Requests
router.post(
  '/cases/:caseId/requests',
  requireIdirRole(['CHAIRPERSON', 'TREASURER', 'SECRETARY', 'COMMITTEE', 'MEMBER']),
  validate({ body: submitRequestSchema }),
  assistanceController.submitRequest
);

router.post(
  '/cases/:caseId/requests/:requestId/review',
  requireIdirRole(['CHAIRPERSON', 'COMMITTEE']),
  validate({ body: reviewRequestSchema }),
  assistanceController.reviewRequest
);

// Disbursements
router.post(
  '/requests/:requestId/disburse',
  requireIdirRole(['CHAIRPERSON', 'TREASURER']),
  validate({ body: disburseSchema }),
  assistanceController.recordDisbursement
);

export const assistanceRoutes = router;
