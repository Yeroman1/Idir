import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/invitations_repository.dart';
import '../../domain/models/invitation_result.dart';

class InvitationState {
  const InvitationState({
    this.isLoading = false,
    this.error,
    this.result,
  });

  final bool isLoading;
  final String? error;
  final BatchInvitationResult? result;

  InvitationState copyWith({
    bool? isLoading,
    String? error,
    BatchInvitationResult? result,
  }) {
    return InvitationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      result: result ?? this.result,
    );
  }
}

class InvitationNotifier extends StateNotifier<InvitationState> {
  InvitationNotifier(this._repository) : super(const InvitationState());

  final InvitationsRepository _repository;

  Future<bool> sendBatch({
    required String idirId,
    required List<String> phoneNumbers,
    int expiresInDays = 7,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final res = await _repository.sendBatchInvitations(
        idirId: idirId,
        phoneNumbers: phoneNumbers,
        expiresInDays: expiresInDays,
      );

      state = state.copyWith(isLoading: false, result: res);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  void reset() {
    state = const InvitationState();
  }
}

final invitationNotifierProvider =
    StateNotifierProvider.autoDispose<InvitationNotifier, InvitationState>((ref) {
  final repo = ref.watch(invitationsRepositoryProvider);
  return InvitationNotifier(repo);
});
