import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../shared/types/index.js';
import { nominationsService } from './nominations.service.js';
import {
  CreateNominationInput,
  RespondNominationInput,
  UpdateStatementInput,
  QueryNominationsInput,
} from './nominations.validation.js';

export class NominationsController {
  async createNomination(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const input = req.body as CreateNominationInput;
      const nomination = await nominationsService.nominateCandidate(
        idirId,
        electionId,
        req.user!.id,
        input
      );

      res.status(201).json({
        success: true,
        message:
          nomination.status === 'ACCEPTED'
            ? 'Candidate self-nomination registered and accepted'
            : 'Nomination submitted successfully; pending nominee acceptance',
        data: nomination,
      });
    } catch (error) {
      next(error);
    }
  }

  async respondToNomination(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId, nominationId } = req.params;
      const input = req.body as RespondNominationInput;
      const updated = await nominationsService.respondToNomination(
        idirId,
        electionId,
        nominationId,
        req.user!.id,
        input
      );

      res.status(200).json({
        success: true,
        message:
          updated.status === 'ACCEPTED'
            ? 'Nomination accepted; candidate will appear on the ballot'
            : 'Nomination declined',
        data: updated,
      });
    } catch (error) {
      next(error);
    }
  }

  async withdrawNomination(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId, nominationId } = req.params;
      const updated = await nominationsService.withdrawNomination(
        idirId,
        electionId,
        nominationId,
        req.user!.id
      );

      res.status(200).json({
        success: true,
        message: 'Nomination withdrawn successfully',
        data: updated,
      });
    } catch (error) {
      next(error);
    }
  }

  async updateStatement(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId, nominationId } = req.params;
      const { statement } = req.body as UpdateStatementInput;
      const updated = await nominationsService.updateCandidateStatement(
        idirId,
        electionId,
        nominationId,
        req.user!.id,
        statement
      );

      res.status(200).json({
        success: true,
        message: 'Candidate statement updated successfully',
        data: updated,
      });
    } catch (error) {
      next(error);
    }
  }

  async listNominations(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const query = req.query as unknown as QueryNominationsInput;
      const list = await nominationsService.listNominations(
        idirId,
        electionId,
        req.user!.id,
        query
      );

      res.status(200).json({
        success: true,
        data: list,
      });
    } catch (error) {
      next(error);
    }
  }

  async getCandidatePage(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId, nominationId } = req.params;
      const candidate = await nominationsService.getCandidatePage(
        idirId,
        electionId,
        nominationId,
        req.user!.id
      );

      res.status(200).json({
        success: true,
        data: candidate,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const nominationsController = new NominationsController();
