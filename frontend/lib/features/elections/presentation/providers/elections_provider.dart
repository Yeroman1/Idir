import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/elections_repository.dart';
import '../../domain/models/election_model.dart';
import '../../domain/models/nomination_model.dart';
import '../../domain/models/vote_receipt_model.dart';

class ElectionCreationState {
  const ElectionCreationState({
    this.isLoading = false,
    this.errorMessage,
    this.createdElection,
  });

  final bool isLoading;
  final String? errorMessage;
  final ElectionModel? createdElection;

  ElectionCreationState copyWith({
    bool? isLoading,
    String? errorMessage,
    ElectionModel? createdElection,
  }) {
    return ElectionCreationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      createdElection: createdElection ?? this.createdElection,
    );
  }
}

class ElectionCreationNotifier extends StateNotifier<ElectionCreationState> {
  ElectionCreationNotifier(this._repository)
      : super(const ElectionCreationState());

  final ElectionsRepository _repository;

  /// Validates settings client-side before dispatching to the backend API.
  String? validateSettings({
    required String title,
    required List<String> roles,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? nominationStartDate,
    DateTime? nominationEndDate,
    required int termLengthMonths,
    required double quorumPercentage,
    required List<String> committeeMemberIds,
  }) {
    if (title.trim().length < 3) {
      return 'Election title must be at least 3 characters';
    }
    if (roles.isEmpty) {
      return 'Please select at least one leadership role to contest';
    }
    if (!endDate.isAfter(startDate)) {
      return 'Election end date must be strictly after start date';
    }
    if (nominationStartDate != null && nominationEndDate != null) {
      if (!nominationEndDate.isAfter(nominationStartDate)) {
        return 'Nomination end date must be after nomination start date';
      }
    }
    if (nominationEndDate != null && nominationEndDate.isAfter(startDate)) {
      return 'Nomination period must conclude on or before voting start date';
    }
    if (termLengthMonths < 1 || termLengthMonths > 120) {
      return 'Term length must be between 1 and 120 months';
    }
    if (quorumPercentage < 1 || quorumPercentage > 100) {
      return 'Quorum percentage must be between 1% and 100%';
    }
    if (committeeMemberIds.isEmpty) {
      return 'At least one neutral election committee member must be assigned';
    }
    return null;
  }

  Future<bool> createElection({
    required String idirId,
    required String title,
    String? description,
    required List<String> roles,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? nominationStartDate,
    DateTime? nominationEndDate,
    required int termLengthMonths,
    required String votingMethod,
    required String ballotType,
    required double quorumPercentage,
    int minMembershipTenureDays = 0,
    bool requiresGoodStanding = true,
    int disputeWindowHours = 48,
    DateTime? handoverDate,
    required List<String> committeeMemberIds,
  }) async {
    final validationError = validateSettings(
      title: title,
      roles: roles,
      startDate: startDate,
      endDate: endDate,
      nominationStartDate: nominationStartDate,
      nominationEndDate: nominationEndDate,
      termLengthMonths: termLengthMonths,
      quorumPercentage: quorumPercentage,
      committeeMemberIds: committeeMemberIds,
    );

    if (validationError != null) {
      state = state.copyWith(errorMessage: validationError, isLoading: false);
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final created = await _repository.createElection(
        idirId: idirId,
        title: title.trim(),
        description: description?.trim(),
        roles: roles,
        startDate: startDate,
        endDate: endDate,
        nominationStartDate: nominationStartDate,
        nominationEndDate: nominationEndDate,
        termLengthMonths: termLengthMonths,
        votingMethod: votingMethod,
        ballotType: ballotType,
        quorumPercentage: quorumPercentage,
        minMembershipTenureDays: minMembershipTenureDays,
        requiresGoodStanding: requiresGoodStanding,
        disputeWindowHours: disputeWindowHours,
        handoverDate: handoverDate,
        committeeMemberIds: committeeMemberIds,
      );

      state = state.copyWith(
        isLoading: false,
        createdElection: created,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void reset() {
    state = const ElectionCreationState();
  }
}

final electionCreationProvider =
    StateNotifierProvider<ElectionCreationNotifier, ElectionCreationState>((ref) {
  final repo = ref.watch(electionsRepositoryProvider);
  return ElectionCreationNotifier(repo);
});

final electionsListProvider =
    FutureProvider.family<List<ElectionModel>, String>((ref, idirId) async {
  final repo = ref.watch(electionsRepositoryProvider);
  return repo.listElections(idirId: idirId);
});

class NominationsQueryArgs extends Equatable {
  const NominationsQueryArgs({
    required this.idirId,
    required this.electionId,
    this.role,
    this.status,
    this.ballotOnly,
  });

  final String idirId;
  final String electionId;
  final String? role;
  final String? status;
  final bool? ballotOnly;

  @override
  List<Object?> get props => [idirId, electionId, role, status, ballotOnly];
}

final nominationsListProvider =
    FutureProvider.family<List<NominationModel>, NominationsQueryArgs>((ref, args) async {
  final repo = ref.watch(electionsRepositoryProvider);
  return repo.listNominations(
    idirId: args.idirId,
    electionId: args.electionId,
    role: args.role,
    status: args.status,
    ballotOnly: args.ballotOnly,
  );
});

class CandidatePageQueryArgs extends Equatable {
  const CandidatePageQueryArgs({
    required this.idirId,
    required this.electionId,
    required this.nominationId,
  });

  final String idirId;
  final String electionId;
  final String nominationId;

  @override
  List<Object?> get props => [idirId, electionId, nominationId];
}

final candidatePageProvider =
    FutureProvider.family<NominationModel, CandidatePageQueryArgs>((ref, args) async {
  final repo = ref.watch(electionsRepositoryProvider);
  return repo.getCandidatePage(
    idirId: args.idirId,
    electionId: args.electionId,
    nominationId: args.nominationId,
  );
});

class NominationActionState {
  const NominationActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.nomination,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final NominationModel? nomination;

  NominationActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    NominationModel? nomination,
  }) {
    return NominationActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
      nomination: nomination ?? this.nomination,
    );
  }
}

class NominationActionNotifier extends StateNotifier<NominationActionState> {
  NominationActionNotifier(this._repository)
      : super(const NominationActionState());

  final ElectionsRepository _repository;

  Future<bool> nominateCandidate({
    required String idirId,
    required String electionId,
    required String role,
    required String nomineeMembershipId,
    String? statement,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final res = await _repository.nominateCandidate(
        idirId: idirId,
        electionId: electionId,
        role: role,
        nomineeMembershipId: nomineeMembershipId,
        statement: statement,
      );
      state = state.copyWith(
        isLoading: false,
        nomination: res,
        successMessage: res.isAccepted
            ? 'Candidate self-nomination accepted!'
            : 'Nomination submitted successfully; pending nominee acceptance.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> respondToNomination({
    required String idirId,
    required String electionId,
    required String nominationId,
    required String action,
    String? statement,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final res = await _repository.respondToNomination(
        idirId: idirId,
        electionId: electionId,
        nominationId: nominationId,
        action: action,
        statement: statement,
      );
      state = state.copyWith(
        isLoading: false,
        nomination: res,
        successMessage: res.isAccepted
            ? 'Nomination accepted! You will appear on the ballot.'
            : 'Nomination declined.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> withdrawNomination({
    required String idirId,
    required String electionId,
    required String nominationId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final res = await _repository.withdrawNomination(
        idirId: idirId,
        electionId: electionId,
        nominationId: nominationId,
      );
      state = state.copyWith(
        isLoading: false,
        nomination: res,
        successMessage: 'Candidacy withdrawn successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> updateStatement({
    required String idirId,
    required String electionId,
    required String nominationId,
    required String statement,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final res = await _repository.updateCandidateStatement(
        idirId: idirId,
        electionId: electionId,
        nominationId: nominationId,
        statement: statement,
      );
      state = state.copyWith(
        isLoading: false,
        nomination: res,
        successMessage: 'Candidate statement updated successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void reset() {
    state = const NominationActionState();
  }
}

final nominationActionProvider =
    StateNotifierProvider<NominationActionNotifier, NominationActionState>((ref) {
  final repo = ref.watch(electionsRepositoryProvider);
  return NominationActionNotifier(repo);
});

/* ==========================================================================
   VOTING PROVIDERS & ACTIONS (Task 3)
   ========================================================================== */

class VotingQueryArgs extends Equatable {
  const VotingQueryArgs({
    required this.idirId,
    required this.electionId,
  });

  final String idirId;
  final String electionId;

  @override
  List<Object?> get props => [idirId, electionId];
}

final votingStatusProvider =
    FutureProvider.family<VotingStatusModel, VotingQueryArgs>((ref, args) async {
  final repo = ref.watch(electionsRepositoryProvider);
  return repo.getVotingStatus(
    idirId: args.idirId,
    electionId: args.electionId,
  );
});

final electionBallotProvider =
    FutureProvider.family<Map<String, dynamic>, VotingQueryArgs>((ref, args) async {
  final repo = ref.watch(electionsRepositoryProvider);
  return repo.getBallot(
    idirId: args.idirId,
    electionId: args.electionId,
  );
});

class VotingActionState {
  const VotingActionState({
    this.isVoting = false,
    this.errorMessage,
    this.successMessage,
    this.lastReceipt,
  });

  final bool isVoting;
  final String? errorMessage;
  final String? successMessage;
  final VoteReceiptModel? lastReceipt;

  bool get isLoading => isVoting;

  VotingActionState copyWith({
    bool? isVoting,
    String? errorMessage,
    String? successMessage,
    VoteReceiptModel? lastReceipt,
  }) {
    return VotingActionState(
      isVoting: isVoting ?? this.isVoting,
      errorMessage: errorMessage,
      successMessage: successMessage,
      lastReceipt: lastReceipt ?? this.lastReceipt,
    );
  }
}

class VotingActionNotifier extends StateNotifier<VotingActionState> {
  VotingActionNotifier(this._repository) : super(const VotingActionState());

  final ElectionsRepository _repository;

  Future<bool> castVote({
    required String idirId,
    required String electionId,
    required String role,
    required String candidateNominationId,
  }) async {
    state = state.copyWith(isVoting: true, errorMessage: null, successMessage: null);
    try {
      final receipt = await _repository.castVote(
        idirId: idirId,
        electionId: electionId,
        role: role,
        candidateNominationId: candidateNominationId,
      );

      state = state.copyWith(
        isVoting: false,
        lastReceipt: receipt,
        successMessage: 'Vote cast successfully for $role!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isVoting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void reset() {
    state = const VotingActionState();
  }
}

final votingActionProvider =
    StateNotifierProvider<VotingActionNotifier, VotingActionState>((ref) {
  final repo = ref.watch(electionsRepositoryProvider);
  return VotingActionNotifier(repo);
});
