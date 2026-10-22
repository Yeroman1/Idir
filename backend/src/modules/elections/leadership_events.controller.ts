import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../shared/types/index.js';
import { leadershipEventsService } from './leadership_events.service.js';

export class LeadershipEventsController {
  async initiateNoConfidence(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { idirId } = req.params;
      const actorUserId = req.user!.id;
      const vote = await leadershipEventsService.initiateNoConfidence(idirId, actorUserId, req.body);

      res.status(201).json({
        success: true,
        data: vote,
        message: 'No-confidence motion initiated successfully',
      });
    } catch (error) {
      next(error);
    }
  }

  async listNoConfidenceVotes(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { idirId } = req.params;
      const actorUserId = req.user!.id;
      const votes = await leadershipEventsService.listNoConfidenceVotes(idirId, actorUserId);

      res.status(200).json({
        success: true,
        data: votes,
      });
    } catch (error) {
      next(error);
    }
  }

  async getNoConfidenceVote(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { idirId, voteId } = req.params;
      const actorUserId = req.user!.id;
      const vote = await leadershipEventsService.getNoConfidenceVote(idirId, voteId, actorUserId);

      res.status(200).json({
        success: true,
        data: vote,
      });
    } catch (error) {
      next(error);
    }
  }

  async castNoConfidenceVote(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { idirId, voteId } = req.params;
      const actorUserId = req.user!.id;
      const result = await leadershipEventsService.castNoConfidenceVote(idirId, voteId, actorUserId, req.body);

      res.status(200).json({
        success: true,
        data: result,
        message: 'Ballot cast successfully',
      });
    } catch (error) {
      next(error);
    }
  }

  async resolveNoConfidenceVote(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { idirId, voteId } = req.params;
      const actorUserId = req.user!.id;
      const result = await leadershipEventsService.resolveNoConfidenceVote(idirId, voteId, actorUserId, req.body);

      res.status(200).json({
        success: true,
        data: result,
        message: result.result.passed
          ? 'No-confidence vote passed! Officer removed and leadership seat vacated.'
          : 'No-confidence vote concluded without officer removal.',
      });
    } catch (error) {
      next(error);
    }
  }

  async getLeadershipVacancies(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { idirId } = req.params;
      const actorUserId = req.user!.id;
      const vacancies = await leadershipEventsService.getLeadershipVacancies(idirId, actorUserId);

      res.status(200).json({
        success: true,
        data: vacancies,
      });
    } catch (error) {
      next(error);
    }
  }

  async appointTemporaryOfficer(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { idirId } = req.params;
      const actorUserId = req.user!.id;
      const appointment = await leadershipEventsService.appointTemporaryOfficer(idirId, actorUserId, req.body);

      res.status(200).json({
        success: true,
        data: appointment,
        message: 'Interim temporary officer appointed successfully',
      });
    } catch (error) {
      next(error);
    }
  }

  async createByElection(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { idirId } = req.params;
      const actorUserId = req.user!.id;
      const election = await leadershipEventsService.createByElection(idirId, actorUserId, req.body);

      res.status(201).json({
        success: true,
        data: election,
        message: 'By-election scheduled successfully',
      });
    } catch (error) {
      next(error);
    }
  }
}

export const leadershipEventsController = new LeadershipEventsController();
