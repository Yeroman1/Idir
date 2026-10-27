import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/invitations_repository.dart';
import '../../domain/models/invitation_result.dart';
import '../../domain/models/received_invitation.dart';

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
    List<String> phoneNumbers = const [],
    List<String> emails = const [],
    int expiresInDays = 7,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final res = await _repository.sendBatchInvitations(
        idirId: idirId,
        phoneNumbers: phoneNumbers,
        emails: emails,
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

class ReceivedInvitationsNotifier
    extends StateNotifier<AsyncValue<List<ReceivedInvitation>>> {
  ReceivedInvitationsNotifier(this._repository, this._ref, [this._userId])
      : super(const AsyncValue.loading()) {
    if (_userId == null) {
      state = const AsyncValue.data([]);
    } else {
      loadReceivedInvitations();
    }
  }

  final InvitationsRepository _repository;
  final Ref _ref;
  final String? _userId;

  Future<void> loadReceivedInvitations() async {
    if (_userId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final list = await _repository.getReceivedInvitations();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> respond(String invitationId, String action) async {
    try {
      await _repository.respondToReceivedInvitation(
        invitationId: invitationId,
        action: action,
      );

      final currentList = state.value ?? [];
      state = AsyncValue.data(
          currentList.where((inv) => inv.id != invitationId).toList());

      if (action.toUpperCase() == 'ACCEPT') {
        await _ref.read(authNotifierProvider.notifier).refreshCurrentUser();
        await _ref.read(activeIdirProvider.notifier).reloadIdirs();
      }
      return true;
    } catch (e) {
      debugPrint('[ReceivedInvitationsNotifier] respond error: $e');
      return false;
    }
  }
}

final receivedInvitationsProvider = StateNotifierProvider.autoDispose<
    ReceivedInvitationsNotifier, AsyncValue<List<ReceivedInvitation>>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repo = ref.watch(invitationsRepositoryProvider);
  return ReceivedInvitationsNotifier(repo, ref, user?.uid);
});
