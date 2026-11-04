import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:idir_app/features/cooperation/data/cooperation_repository.dart';
import 'package:idir_app/features/cooperation/data/rest_cooperation_repository.dart';
import 'package:idir_app/features/cooperation/domain/models/cooperation_models.dart';

// ── List providers ─────────────────────────────────────────────────────────────

final cooperationListProvider =
    FutureProvider.family<List<CooperationAgreement>, String>((ref, idirId) async {
  final repo = ref.watch(cooperationRepositoryProvider);
  return repo.listCooperations(idirId);
});

final cooperationDetailProvider =
    FutureProvider.family<CooperationAgreement, (String, String)>((ref, args) async {
  final (idirId, agreementId) = args;
  final repo = ref.watch(cooperationRepositoryProvider);
  return repo.getCooperation(idirId, agreementId);
});

final initiativeListProvider =
    FutureProvider.family<List<JointInitiative>, (String, String)>((ref, args) async {
  final (idirId, agreementId) = args;
  final repo = ref.watch(cooperationRepositoryProvider);
  return repo.listInitiatives(idirId, agreementId);
});

final initiativeDetailProvider =
    FutureProvider.family<JointInitiative, (String, String, String)>((ref, args) async {
  final (idirId, agreementId, initiativeId) = args;
  final repo = ref.watch(cooperationRepositoryProvider);
  return repo.getInitiative(idirId, agreementId, initiativeId);
});

final announcementListProvider =
    FutureProvider.family<List<CrossIdirAnnouncement>, (String, String)>((ref, args) async {
  final (idirId, agreementId) = args;
  final repo = ref.watch(cooperationRepositoryProvider);
  return repo.listAnnouncements(idirId, agreementId);
});

final emergencyListProvider =
    FutureProvider.family<List<CrossIdirEmergency>, (String, String)>((ref, args) async {
  final (idirId, agreementId) = args;
  final repo = ref.watch(cooperationRepositoryProvider);
  return repo.listEmergencies(idirId, agreementId);
});

final financialCommitmentListProvider =
    FutureProvider.family<List<JointFinancialCommitment>, (String, String)>((ref, args) async {
  final (idirId, agreementId) = args;
  final repo = ref.watch(cooperationRepositoryProvider);
  return repo.listCommitments(idirId, agreementId);
});

// ── Action Notifier ────────────────────────────────────────────────────────────

class CooperationActionNotifier extends StateNotifier<AsyncValue<void>> {
  CooperationActionNotifier(this._repo) : super(const AsyncValue.data(null));

  final CooperationRepository _repo;

  Future<void> proposeCooperation(
    String idirId, {
    required String targetIdirId,
    required String purpose,
    required String description,
    int? proposedDuration,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.proposeCooperation(
        idirId,
        targetIdirId: targetIdirId,
        purpose: purpose,
        description: description,
        proposedDuration: proposedDuration,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> respondToCooperation(
    String idirId,
    String agreementId, {
    required String action,
    String? rejectionReason,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.respondToCooperation(
        idirId,
        agreementId,
        action: action,
        rejectionReason: rejectionReason,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> endCooperation(String idirId, String agreementId, String reason) async {
    state = const AsyncValue.loading();
    try {
      await _repo.endCooperation(idirId, agreementId, reason);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createInitiative(
    String idirId,
    String agreementId, {
    required String title,
    required String description,
    required String objectives,
    required String category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.createInitiative(
        idirId,
        agreementId,
        title: title,
        description: description,
        objectives: objectives,
        category: category,
        startDate: startDate,
        endDate: endDate,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addInitiativeUpdate(
    String idirId,
    String agreementId,
    String initiativeId, {
    required String content,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addInitiativeUpdate(idirId, agreementId, initiativeId, content: content);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addInitiativeTask(
    String idirId,
    String agreementId,
    String initiativeId, {
    required String title,
    String? description,
    required String responsibleIdirId,
    DateTime? dueDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addInitiativeTask(
        idirId,
        agreementId,
        initiativeId,
        title: title,
        description: description,
        responsibleIdirId: responsibleIdirId,
        dueDate: dueDate,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> completeTask(
    String idirId,
    String agreementId,
    String initiativeId,
    String taskId,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateInitiative(idirId, agreementId, initiativeId, {
        'taskId': taskId,
        'isCompleted': true,
      });
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createAnnouncement(
    String idirId,
    String agreementId, {
    required String title,
    required String body,
    required String category,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.createAnnouncement(idirId, agreementId, title: title, body: body, category: category);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> withdrawAnnouncement(String idirId, String agreementId, String announcementId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.withdrawAnnouncement(idirId, agreementId, announcementId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createEmergency(
    String idirId,
    String agreementId, {
    required String title,
    required String description,
    required String emergencyType,
    required String urgency,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.createEmergency(
        idirId,
        agreementId,
        title: title,
        description: description,
        emergencyType: emergencyType,
        urgency: urgency,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> respondToEmergency(
    String idirId,
    String agreementId,
    String emergencyId, {
    required String message,
    String? commitmentNote,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.respondToEmergency(
        idirId,
        agreementId,
        emergencyId,
        message: message,
        commitmentNote: commitmentNote,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> closeEmergency(
    String idirId,
    String agreementId,
    String emergencyId,
    String outcomeSummary,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.closeEmergency(idirId, agreementId, emergencyId, outcomeSummary);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createCommitment(
    String idirId,
    String agreementId, {
    required double amountCommitted,
    required String purpose,
    String? initiativeId,
  }) => createFinancialCommitment(idirId, agreementId, amountCommitted: amountCommitted, purpose: purpose, initiativeId: initiativeId);

  Future<void> createFinancialCommitment(
    String idirId,
    String agreementId, {
    required double amountCommitted,
    required String purpose,
    String? initiativeId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.createCommitment(
        idirId,
        agreementId,
        amountCommitted: amountCommitted,
        purpose: purpose,
        initiativeId: initiativeId,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> authorizeCommitment(String idirId, String agreementId, String commitmentId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.authorizeCommitment(idirId, agreementId, commitmentId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> confirmCommitment(
    String idirId,
    String agreementId,
    String commitmentId, {
    required double amountConfirmed,
    String? reconciliationNote,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.confirmCommitment(
        idirId,
        agreementId,
        commitmentId,
        amountConfirmed: amountConfirmed,
        reconciliationNote: reconciliationNote,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final cooperationActionProvider =
    StateNotifierProvider<CooperationActionNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(cooperationRepositoryProvider);
  return CooperationActionNotifier(repo);
});
