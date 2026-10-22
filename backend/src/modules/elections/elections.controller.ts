import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../shared/types/index.js';
import { electionsService } from './elections.service.js';
import {
  CreateElectionInput,
  UpdateElectionInput,
  QueryElectionsInput,
  CancelElectionInput,
} from './elections.validation.js';

export class ElectionsController {
  async createElection(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const idirId = req.params.idirId;
      const input = req.body as CreateElectionInput;
      const election = await electionsService.createElection(
        idirId,
        req.user!.id,
        input
      );

      res.status(201).json({
        success: true,
        message: 'Election setup successfully created',
        data: election,
      });
    } catch (error) {
      next(error);
    }
  }

  async getElection(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const election = await electionsService.getElectionById(
        idirId,
        electionId,
        req.user!.id
      );

      res.status(200).json({
        success: true,
        data: election,
      });
    } catch (error) {
      next(error);
    }
  }

  async listElections(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const idirId = req.params.idirId;
      const query = req.query as unknown as QueryElectionsInput;
      const result = await electionsService.listIdirElections(
        idirId,
        req.user!.id,
        query
      );

      res.status(200).json({
        success: true,
        data: result.items,
        pagination: result.pagination,
      });
    } catch (error) {
      next(error);
    }
  }

  async updateElection(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const input = req.body as UpdateElectionInput;
      const updated = await electionsService.updateElection(
        idirId,
        electionId,
        req.user!.id,
        input
      );

      res.status(200).json({
        success: true,
        message: 'Election settings updated successfully',
        data: updated,
      });
    } catch (error) {
      next(error);
    }
  }

  async cancelElection(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const { reason } = req.body as CancelElectionInput;
      const cancelled = await electionsService.cancelElection(
        idirId,
        electionId,
        req.user!.id,
        reason
      );

      res.status(200).json({
        success: true,
        message: 'Election cancelled successfully',
        data: cancelled,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const electionsController = new ElectionsController();
