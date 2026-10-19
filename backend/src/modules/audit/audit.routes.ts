import { Router } from 'express';
import { auditController } from './audit.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';

const router = Router({ mergeParams: true });

router.use(authenticate);

router.get(
  '/',
  requireIdirRole(['CHAIRPERSON', 'AUDITOR']),
  auditController.listLogs
);

export const auditRoutes = router;
