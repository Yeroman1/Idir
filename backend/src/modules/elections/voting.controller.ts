import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../shared/types/index.js';
import { votingService } from './voting.service.js';
import { CastVoteInput, CastBatchVotesInput } from './voting.validation.js';

export class VotingController {
  async castVote(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const input = req.body as CastVoteInput;
      const result = await votingService.castVote(
        idirId,
        electionId,
        req.user!.id,
        input
      );

      res.status(201).json({
        success: true,
        message: result.message,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async castBatchVotes(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const input = req.body as CastBatchVotesInput;
      const results = await votingService.castBatchVotes(
        idirId,
        electionId,
        req.user!.id,
        input
      );

      res.status(201).json({
        success: true,
        message: `Successfully recorded ${results.length} votes`,
        data: results,
      });
    } catch (error) {
      next(error);
    }
  }

  async getMemberVotingStatus(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const status = await votingService.getMemberVotingStatus(
        idirId,
        electionId,
        req.user!.id
      );

      res.status(200).json({
        success: true,
        data: status,
      });
    } catch (error) {
      next(error);
    }
  }

  async getElectionBallot(
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const { idirId, electionId } = req.params;
      const ballot = await votingService.getElectionBallot(
        idirId,
        electionId,
        req.user!.id
      );

      res.status(200).json({
        success: true,
        data: ballot,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const votingController = new VotingController();
