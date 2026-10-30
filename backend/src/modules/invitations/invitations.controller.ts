import { Request, Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../shared/types/index.js';
import { invitationsService } from './invitations.service.js';
import { BatchInviteInput } from './invitations.validation.js';

export class InvitationsController {
  /**
   * Dispatch batch invitations (Creator / Officer).
   */
  async batchInvite(
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const idirId = req.params.idirId;
      const { phoneNumbers = [], emails = [], expiresInDays = 7 } = req.body as BatchInviteInput;

      const result = await invitationsService.sendBatchInvitations(
        idirId,
        req.user!.id,
        phoneNumbers,
        expiresInDays,
        { emails }
      );

      res.status(201).json({
        success: true,
        message: `Successfully processed ${result.sentCount} invitation(s)`,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * Check if a phone number or email corresponds to a registered user before inviting.
   * GET /api/v1/idirs/:idirId/invitations/check-user?phone=... or ?email=...
   */
  async checkUser(
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const idirId = req.params.idirId || (req.query.idirId as string) || '';
      const identifier = (req.query.email as string) || (req.query.phone as string) || '';
      const actorId = (req as AuthenticatedRequest).user?.id || 'system';

      const result = await invitationsService.checkUserRegistration(
        idirId,
        actorId,
        identifier
      );

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * Public view-only lookup for an invitation link.
   */
  async verifyPublic(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const rawToken = (req.query.token as string) || req.params.token;
      const data = await invitationsService.verifyPublicInvitation(rawToken);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * Authenticated user responds to an invitation (ACCEPT or DECLINE).
   */
  async respondPublic(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { token, action } = req.body;
      const result = await invitationsService.respondToInvitation(
        token,
        req.user!.id,
        action
      );

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * List all invitations for an Idir (officer management).
   */
  async listIdirInvitations(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const idirId = req.params.idirId;
      const invitations = await invitationsService.listIdirInvitations(idirId, req.user!.id);

      res.status(200).json({
        success: true,
        data: invitations,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * Revoke a single invitation.
   */
  async revokeInvitation(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { idirId, invitationId } = req.params;
      const result = await invitationsService.revokeInvitation(idirId, req.user!.id, invitationId);

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * Revoke all pending invitations for an Idir.
   */
  async revokeAllPending(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const idirId = req.params.idirId;
      const result = await invitationsService.revokeAllPending(idirId, req.user!.id);

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * Get pending invitations received by the current user.
   */
  async getReceivedInvitations(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const invitations = await invitationsService.getReceivedInvitations(req.user!.id);
      res.status(200).json({
        success: true,
        data: invitations,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * Authenticated user responds to a received invitation by ID.
   */
  async respondById(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { invitationId } = req.params;
      const { action } = req.body;
      const result = await invitationsService.respondToInvitationById(
        invitationId,
        req.user!.id,
        action
      );

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const invitationsController = new InvitationsController();
