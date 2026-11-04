import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../shared/types/index.js';
import { cooperationService } from './cooperation.service.js';

export async function listAgreements(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId } = req.params;
    const data = await cooperationService.listAgreements(idirId);
    res.status(200).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function getAgreement(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId } = req.params;
    const data = await cooperationService.getAgreement(idirId, agreementId);
    res.status(200).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function proposeCooperation(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId } = req.params;
    const data = await cooperationService.proposeCooperation(idirId, req.body, req.user!.id);
    res.status(201).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function respondToCooperation(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId } = req.params;
    const data = await cooperationService.respondToCooperation(idirId, agreementId, req.body, req.user!.id);
    res.status(200).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function endCooperation(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId } = req.params;
    const data = await cooperationService.endCooperation(idirId, agreementId, req.body, req.user!.id);
    res.status(200).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

// ── Initiatives ──

export async function listInitiatives(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId } = req.params;
    const data = await cooperationService.listInitiatives(idirId, agreementId);
    res.status(200).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function getInitiative(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId, initiativeId } = req.params;
    const data = await cooperationService.getInitiative(idirId, agreementId, initiativeId);
    res.status(200).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function createInitiative(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId } = req.params;
    const data = await cooperationService.createInitiative(idirId, agreementId, req.body, req.user!.id);
    res.status(201).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function updateInitiative(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId, initiativeId } = req.params;
    const data = await cooperationService.updateInitiative(idirId, agreementId, initiativeId, req.body, req.user!.id);
    res.status(200).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function addInitiativeUpdate(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId, initiativeId } = req.params;
    const data = await cooperationService.addInitiativeUpdate(idirId, agreementId, initiativeId, req.body, req.user!.id);
    res.status(201).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function addInitiativeTask(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId, initiativeId } = req.params;
    const data = await cooperationService.addInitiativeTask(idirId, agreementId, initiativeId, req.body);
    res.status(201).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

// ── Announcements ──

export async function listAnnouncements(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId } = req.params;
    const data = await cooperationService.listAnnouncements(idirId, agreementId);
    res.status(200).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function createAnnouncement(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId } = req.params;
    const data = await cooperationService.createAnnouncement(idirId, agreementId, req.body, req.user!.id);
    res.status(201).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function updateAnnouncement(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId, announcementId } = req.params;
    const data = await cooperationService.updateAnnouncement(idirId, agreementId, announcementId, req.body, req.user!.id);
    res.status(200).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function withdrawAnnouncement(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId, announcementId } = req.params;
    await cooperationService.withdrawAnnouncement(idirId, agreementId, announcementId, req.user!.id);
    res.status(200).json({ success: true, message: 'Cross-Idir announcement withdrawn' });
  } catch (err) {
    next(err);
  }
}

// ── Emergencies ──

export async function listEmergencies(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId } = req.params;
    const data = await cooperationService.listEmergencies(idirId, agreementId);
    res.status(200).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function createEmergency(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId } = req.params;
    const data = await cooperationService.createEmergency(idirId, agreementId, req.body, req.user!.id);
    res.status(201).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function respondToEmergency(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId, emergencyId } = req.params;
    const data = await cooperationService.respondToEmergency(idirId, agreementId, emergencyId, req.body, req.user!.id);
    res.status(201).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function closeEmergency(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId, emergencyId } = req.params;
    await cooperationService.closeEmergency(idirId, agreementId, emergencyId, req.body, req.user!.id);
    res.status(200).json({ success: true, message: 'Emergency closed and outcome summary recorded' });
  } catch (err) {
    next(err);
  }
}

// ── Financial Commitments ──

export async function listCommitments(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId } = req.params;
    const data = await cooperationService.listCommitments(idirId, agreementId);
    res.status(200).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function createCommitment(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId } = req.params;
    const data = await cooperationService.createCommitment(idirId, agreementId, req.body, req.user!.id);
    res.status(201).json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

export async function authorizeCommitment(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId, commitmentId } = req.params;
    await cooperationService.authorizeCommitment(idirId, agreementId, commitmentId, req.user!.id);
    res.status(200).json({ success: true, message: 'Financial commitment authorized' });
  } catch (err) {
    next(err);
  }
}

export async function confirmCommitment(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const { idirId, agreementId, commitmentId } = req.params;
    await cooperationService.confirmCommitment(idirId, agreementId, commitmentId, req.body, req.user!.id);
    res.status(200).json({ success: true, message: 'Financial commitment confirmed and reconciled' });
  } catch (err) {
    next(err);
  }
}

