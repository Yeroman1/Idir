import { Router } from 'express';
import { invitationsController } from './invitations.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { validate } from '../../middleware/validate.js';
import { publicInvitationLimiter } from '../../middleware/rateLimiter.js';
import { batchInviteSchema } from './invitations.validation.js';

// ─── Scoped Nested Routes: /api/v1/idirs/:idirId/invitations ───────────────────
const idirRouter = Router({ mergeParams: true });

// Check user registration by phone or email (open to avoid 401 token expiration drops)
idirRouter.get('/check-user', invitationsController.checkUser);


idirRouter.use(authenticate);

// Batch invitation endpoint: POST /api/v1/idirs/:idirId/invitations/batch
idirRouter.post(
  '/batch',
  validate({ body: batchInviteSchema }),
  invitationsController.batchInvite
);

// Check user registration by phone: GET /api/v1/idirs/:idirId/invitations/check-user?phone=...


// List invitations for this Idir: GET /api/v1/idirs/:idirId/invitations
idirRouter.get('/', invitationsController.listIdirInvitations);

// Revoke a single invitation: POST /api/v1/idirs/:idirId/invitations/:invitationId/revoke
idirRouter.post('/:invitationId/revoke', invitationsController.revokeInvitation);

// Revoke all pending invitations: POST /api/v1/idirs/:idirId/invitations/revoke-all
idirRouter.post('/revoke-all', invitationsController.revokeAllPending);

export const invitationRoutes = idirRouter;

// ─── Public Landing Routes: /api/v1/invitations ────────────────────────────────
const publicRouter = Router();

// Public check user registration by phone or email
publicRouter.get('/check-user', invitationsController.checkUser);

// Public view-only token lookup (rate-limited)
// GET /api/v1/invitations/verify?token=...
publicRouter.get('/verify', publicInvitationLimiter, invitationsController.verifyPublic);
publicRouter.get('/verify/:token', publicInvitationLimiter, invitationsController.verifyPublic);

// Authenticated respond (Accept / Decline via raw token)
// POST /api/v1/invitations/respond
publicRouter.post('/respond', authenticate, invitationsController.respondPublic);

// Authenticated list of pending invitations received by the current user
// GET /api/v1/invitations/received
publicRouter.get('/received', authenticate, invitationsController.getReceivedInvitations);

// Authenticated respond to a received invitation by ID
// POST /api/v1/invitations/:invitationId/respond
publicRouter.post('/:invitationId/respond', authenticate, invitationsController.respondById);

export const publicInvitationRoutes = publicRouter;
