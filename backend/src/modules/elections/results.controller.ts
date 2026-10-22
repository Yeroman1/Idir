import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../shared/types/index.js';
import { resultsService } from './results.service.js';
import {
  TallyVotesInput,
  FileDisputeInput,
  ResolveDisputeInput,
  TriggerRunoffInput,
} from './results.validation.js';

export class ResultsController {
  async tallyVotes(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const input = req.body as TallyVotesInput;
      const results = await resultsService.tallyVotes(
        idirId,
        electionId,
        req.user!.id,
        input
      );

      res.status(200).json({
        success: true,
        message: results.message,
        data: results,
      });
    } catch (error) {
      next(error);
    }
  }

  async getResults(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const results = await resultsService.getResults(idirId, electionId);

      res.status(200).json({
        success: true,
        data: results,
      });
    } catch (error) {
      next(error);
    }
  }

  async fileDispute(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const input = req.body as FileDisputeInput;
      const dispute = await resultsService.fileDispute(
        idirId,
        electionId,
        req.user!.id,
        input
      );

      res.status(201).json({
        success: true,
        message: 'Election dispute filed successfully and is under committee review',
        data: dispute,
      });
    } catch (error) {
      next(error);
    }
  }

  async listDisputes(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const disputes = await resultsService.listDisputes(idirId, electionId);

      res.status(200).json({
        success: true,
        data: disputes,
      });
    } catch (error) {
      next(error);
    }
  }

  async resolveDispute(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId, disputeId } = req.params;
      const input = req.body as ResolveDisputeInput;
      const dispute = await resultsService.resolveDispute(
        idirId,
        electionId,
        disputeId,
        req.user!.id,
        input
      );

      res.status(200).json({
        success: true,
        message: `Dispute has been ${dispute.status.toLowerCase()}`,
        data: dispute,
      });
    } catch (error) {
      next(error);
    }
  }

  async certifyElection(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const certification = await resultsService.certifyElection(
        idirId,
        electionId,
        req.user!.id
      );

      res.status(200).json({
        success: true,
        message: certification.message,
        data: certification,
      });
    } catch (error) {
      next(error);
    }
  }

  async triggerRunoff(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const input = req.body as TriggerRunoffInput;
      const runoff = await resultsService.triggerRunoff(
        idirId,
        electionId,
        req.user!.id,
        input
      );

      res.status(200).json({
        success: true,
        message: runoff.message,
        data: runoff,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const resultsController = new ResultsController();
