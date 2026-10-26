import express, { Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { env } from './config/env.js';
import { generalLimiter } from './middleware/rateLimiter.js';
import { errorHandler } from './middleware/errorHandler.js';
import { NotFoundError } from './shared/errors/AppError.js';
import { docsRouter } from './docs/openapi.js';

// Route imports
import { authRoutes } from './modules/auth/auth.routes.js';
import { usersRoutes } from './modules/users/users.routes.js';
import { idirRoutes } from './modules/idirs/idirs.routes.js';
import { membershipRoutes } from './modules/memberships/memberships.routes.js';
import { contributionRoutes } from './modules/contributions/contributions.routes.js';
import { expenseRoutes } from './modules/expenses/expenses.routes.js';
import { assistanceRoutes } from './modules/assistance/assistance.routes.js';
import { ikubRoutes } from './modules/ikub/ikub.routes.js';
import { meetingRoutes } from './modules/meetings/meetings.routes.js';
import {
  announcementRoutes,
  notificationRoutes,
} from './modules/notifications/notifications.routes.js';
import { reportRoutes } from './modules/reports/reports.routes.js';
import { auditRoutes } from './modules/audit/audit.routes.js';
import {
  invitationRoutes,
  publicInvitationRoutes,
} from './modules/invitations/invitations.routes.js';
import { electionRoutes } from './modules/elections/elections.routes.js';
import { chatRoutes } from './modules/chat/chat.routes.js';

export const app = express();

// Security & Parsing
app.disable('x-powered-by');
app.use(helmet());
app.use(
  cors({
    origin:
      env.CORS_ORIGIN === '*'
        ? true
        : env.CORS_ORIGIN.split(',').map((o) => o.trim()),
    credentials: true,
  })
);
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(generalLimiter);

// OpenAPI Documentation
app.use('/api/docs', docsRouter);
app.use(`${env.API_PREFIX}/docs`, docsRouter);

// Health Check
app.get('/health', (_req: Request, res: Response) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});
app.get(`${env.API_PREFIX}/health`, (_req: Request, res: Response) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API Version 1 Routes
const api = express.Router();

api.use('/auth', authRoutes);
api.use('/users', usersRoutes);
api.use('/notifications', notificationRoutes);
api.use('/invitations', publicInvitationRoutes);

// Idir and Scoped Nested Resources
api.use('/idirs', idirRoutes);
api.use('/idirs/:idirId/members', membershipRoutes);
api.use('/idirs/:idirId/contributions', contributionRoutes);
api.use('/idirs/:idirId/expenses', expenseRoutes);
api.use('/idirs/:idirId/assistance', assistanceRoutes);
api.use('/idirs/:idirId/ikub', ikubRoutes);
api.use('/idirs/:idirId/meetings', meetingRoutes);
api.use('/idirs/:idirId/announcements', announcementRoutes);
api.use('/idirs/:idirId/reports', reportRoutes);
api.use('/idirs/:idirId/audit', auditRoutes);
api.use('/idirs/:idirId/invitations', invitationRoutes);
api.use('/idirs/:idirId/elections', electionRoutes);
api.use('/idirs/:idirId/chat', chatRoutes);

app.use(env.API_PREFIX, api);

// 404 Handler
app.use((_req: Request, _res: Response, next) => {
  next(new NotFoundError('The requested endpoint was not found on this server'));
});

// Centralized Error Handling
app.use(errorHandler);
