import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';
import { requireActiveIdir } from '../../middleware/assertIdirActive.js';
import { validate } from '../../middleware/validate.js';
import {
  COOPERATION_LEADERS,
  INITIATIVE_MANAGERS,
  FINANCIAL_OFFICERS,
} from './cooperation.service.js';
import {
  proposeCooperationSchema,
  respondCooperationSchema,
  endCooperationSchema,
  createInitiativeSchema,
  updateInitiativeSchema,
  addInitiativeUpdateSchema,
  addInitiativeTaskSchema,
  createCrossAnnouncementSchema,
  updateCrossAnnouncementSchema,
  createCrossEmergencySchema,
  respondCrossEmergencySchema,
  closeCrossEmergencySchema,
  createFinancialCommitmentSchema,
  confirmFinancialCommitmentSchema,
} from './cooperation.validation.js';
import * as controller from './cooperation.controller.js';

export const cooperationRoutes = Router({ mergeParams: true });

// All routes require authentication and active Idir status
cooperationRoutes.use(authenticate, requireActiveIdir());

// ── Cooperation Agreements ───────────────────────────────────────────────────

cooperationRoutes.get(
  '/',
  requireIdirRole(['CHAIRPERSON', 'OFFICER', 'SECRETARY', 'TREASURER', 'COMMITTEE', 'MEMBER'] as any),
  controller.listAgreements
);

cooperationRoutes.get(
  '/:agreementId',
  requireIdirRole(['CHAIRPERSON', 'OFFICER', 'SECRETARY', 'TREASURER', 'COMMITTEE', 'MEMBER'] as any),
  controller.getAgreement
);

cooperationRoutes.post(
  '/',
  requireIdirRole(COOPERATION_LEADERS as any),
  validate({ body: proposeCooperationSchema }),
  controller.proposeCooperation
);

cooperationRoutes.post(
  '/:agreementId/respond',
  requireIdirRole(COOPERATION_LEADERS as any),
  validate({ body: respondCooperationSchema }),
  controller.respondToCooperation
);

cooperationRoutes.post(
  '/:agreementId/end',
  requireIdirRole(COOPERATION_LEADERS as any),
  validate({ body: endCooperationSchema }),
  controller.endCooperation
);

// ── Joint Community Initiatives ──────────────────────────────────────────────

cooperationRoutes.get(
  '/:agreementId/initiatives',
  requireIdirRole(['CHAIRPERSON', 'OFFICER', 'SECRETARY', 'TREASURER', 'COMMITTEE', 'MEMBER'] as any),
  controller.listInitiatives
);

cooperationRoutes.get(
  '/:agreementId/initiatives/:initiativeId',
  requireIdirRole(['CHAIRPERSON', 'OFFICER', 'SECRETARY', 'TREASURER', 'COMMITTEE', 'MEMBER'] as any),
  controller.getInitiative
);

cooperationRoutes.post(
  '/:agreementId/initiatives',
  requireIdirRole(INITIATIVE_MANAGERS as any),
  validate({ body: createInitiativeSchema }),
  controller.createInitiative
);

cooperationRoutes.patch(
  '/:agreementId/initiatives/:initiativeId',
  requireIdirRole(INITIATIVE_MANAGERS as any),
  validate({ body: updateInitiativeSchema }),
  controller.updateInitiative
);

cooperationRoutes.post(
  '/:agreementId/initiatives/:initiativeId/updates',
  requireIdirRole(INITIATIVE_MANAGERS as any),
  validate({ body: addInitiativeUpdateSchema }),
  controller.addInitiativeUpdate
);

cooperationRoutes.post(
  '/:agreementId/initiatives/:initiativeId/tasks',
  requireIdirRole(INITIATIVE_MANAGERS as any),
  validate({ body: addInitiativeTaskSchema }),
  controller.addInitiativeTask
);

// ── Cross-Idir Announcements ─────────────────────────────────────────────────

cooperationRoutes.get(
  '/:agreementId/announcements',
  requireIdirRole(['CHAIRPERSON', 'OFFICER', 'SECRETARY', 'TREASURER', 'COMMITTEE', 'MEMBER'] as any),
  controller.listAnnouncements
);

cooperationRoutes.post(
  '/:agreementId/announcements',
  requireIdirRole(COOPERATION_LEADERS as any),
  validate({ body: createCrossAnnouncementSchema }),
  controller.createAnnouncement
);

cooperationRoutes.patch(
  '/:agreementId/announcements/:announcementId',
  requireIdirRole(COOPERATION_LEADERS as any),
  validate({ body: updateCrossAnnouncementSchema }),
  controller.updateAnnouncement
);

cooperationRoutes.post(
  '/:agreementId/announcements/:announcementId/withdraw',
  requireIdirRole(COOPERATION_LEADERS as any),
  controller.withdrawAnnouncement
);

// ── Emergency Coordination ───────────────────────────────────────────────────

cooperationRoutes.get(
  '/:agreementId/emergencies',
  requireIdirRole(['CHAIRPERSON', 'OFFICER', 'SECRETARY', 'TREASURER', 'COMMITTEE', 'MEMBER'] as any),
  controller.listEmergencies
);

cooperationRoutes.post(
  '/:agreementId/emergencies',
  requireIdirRole(INITIATIVE_MANAGERS as any),
  validate({ body: createCrossEmergencySchema }),
  controller.createEmergency
);

cooperationRoutes.post(
  '/:agreementId/emergencies/:emergencyId/respond',
  requireIdirRole(INITIATIVE_MANAGERS as any),
  validate({ body: respondCrossEmergencySchema }),
  controller.respondToEmergency
);

cooperationRoutes.post(
  '/:agreementId/emergencies/:emergencyId/close',
  requireIdirRole(INITIATIVE_MANAGERS as any),
  validate({ body: closeCrossEmergencySchema }),
  controller.closeEmergency
);

// ── Optional Joint Financial Support ─────────────────────────────────────────

cooperationRoutes.get(
  '/:agreementId/commitments',
  requireIdirRole(['CHAIRPERSON', 'OFFICER', 'SECRETARY', 'TREASURER', 'COMMITTEE', 'MEMBER'] as any),
  controller.listCommitments
);

cooperationRoutes.post(
  '/:agreementId/commitments',
  requireIdirRole(FINANCIAL_OFFICERS as any),
  validate({ body: createFinancialCommitmentSchema }),
  controller.createCommitment
);

cooperationRoutes.post(
  '/:agreementId/commitments/:commitmentId/authorize',
  requireIdirRole(FINANCIAL_OFFICERS as any),
  controller.authorizeCommitment
);

cooperationRoutes.post(
  '/:agreementId/commitments/:commitmentId/confirm',
  requireIdirRole(FINANCIAL_OFFICERS as any),
  validate({ body: confirmFinancialCommitmentSchema }),
  controller.confirmCommitment
);
