import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/elections_repository.dart';
import '../../domain/models/election_model.dart';

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
