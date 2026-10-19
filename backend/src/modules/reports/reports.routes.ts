import { Router } from 'express';
import { reportsController } from './reports.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';

const router = Router({ mergeParams: true });

router.use(authenticate);

// Financial summary report (accessible to Chairperson, Treasurer, and Auditor)
router.get(
  '/finances',
  requireIdirRole(['CHAIRPERSON', 'TREASURER', 'AUDITOR']),
  reportsController.getIdirFinancialReport
);

// Individual member contribution ledger
router.get(
  '/members/:membershipId/contributions',
  requireIdirRole(['CHAIRPERSON', 'TREASURER', 'AUDITOR', 'MEMBER']),
  reportsController.getMemberContributionReport
);

export const reportRoutes = router;
