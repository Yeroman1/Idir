import { Router } from 'express';
import { reportsController } from './reports.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';

const router = Router({ mergeParams: true });

router.use(authenticate);

// Financial summary report (transparent read-only access for members and officers)
router.get(
  '/finances',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  reportsController.getIdirFinancialReport
);

// Exportable financial report (CSV / JSON format with period covered and date generated)
router.get(
  '/export',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  reportsController.exportFinancialReport
);

// Individual member contribution ledger
router.get(
  '/members/:membershipId/contributions',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  reportsController.getMemberContributionReport
);

export const reportRoutes = router;
