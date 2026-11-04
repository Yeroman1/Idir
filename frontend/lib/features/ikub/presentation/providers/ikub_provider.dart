import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../../domain/models/ikub_models.dart';
import '../../data/ikub_repository.dart';

final activeIkubProvider =
    StateNotifierProvider<ActiveIkubNotifier, AsyncValue<IkubGroupModel?>>((ref) {
  final repo = ref.watch(ikubRepositoryProvider);
  final activeIdir = ref.watch(currentActiveIdirProvider);
  return ActiveIkubNotifier(repo, activeIdir?.id);
});

class ActiveIkubNotifier extends StateNotifier<AsyncValue<IkubGroupModel?>> {
  ActiveIkubNotifier(this._repo, this._idirId) : super(const AsyncValue.loading()) {
    loadActiveIkub();
  }

  final IkubRepository _repo;
  final String? _idirId;

  Future<void> loadActiveIkub() async {
    final idirId = _idirId;
    if (idirId == null) {
      state = const AsyncValue.data(null);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final group = await _repo.getActiveGroup(idirId);
      state = AsyncValue.data(group);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    final idirId = _idirId;
    if (idirId == null) return;
    try {
      final group = await _repo.getActiveGroup(idirId);
      state = AsyncValue.data(group);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<IkubGroupModel> createGroup({
    required String name,
    String? description,
    required double contributionAmount,
    String frequency = 'WEEKLY',
    required DateTime startDate,
    int totalRounds = 10,
    String payoutRule = 'LOTTERY',
    int winnersPerRound = 1,
    String drawMode = 'DIGITAL_LOTTERY',
  }) async {
    final idirId = _idirId;
    if (idirId == null) throw Exception('No active Idir selected');
    final group = await _repo.createGroup(
      idirId,
      name: name,
      description: description,
      contributionAmount: contributionAmount,
      frequency: frequency,
      startDate: startDate,
      totalRounds: totalRounds,
      payoutRule: payoutRule,
      winnersPerRound: winnersPerRound,
      drawMode: drawMode,
    );
    await refresh();
    return group;
  }

  Future<void> requestToJoin(String membershipId, {String? note}) async {
    final idirId = _idirId;
    final current = state.valueOrNull;
    if (idirId == null || current == null) return;
    await _repo.requestToJoin(idirId, current.id, membershipId, note: note);
    await refresh();
  }

  Future<Map<String, dynamic>> drawLottery(
    String roundId, {
    String? manualWinnerId,
    String? note,
    bool? isRedraw,
    String? redrawReason,
  }) async {
    final idirId = _idirId;
    final current = state.valueOrNull;
    if (idirId == null || current == null) throw Exception('No active Ikub');
    final res = await _repo.drawLottery(
      idirId,
      current.id,
      roundId,
      manualWinnerId: manualWinnerId,
      note: note,
      isRedraw: isRedraw,
      redrawReason: redrawReason,
    );
    await refresh();
    return res;
  }

  Future<void> recordContribution({
    required String roundId,
    required String participantId,
    required double amount,
    String paymentMethod = 'CASH',
    String? paymentReference,
  }) async {
    final idirId = _idirId;
    final current = state.valueOrNull;
    if (idirId == null || current == null) return;
    await _repo.recordContribution(
      idirId,
      current.id,
      roundId: roundId,
      participantId: participantId,
      amount: amount,
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
    );
    await refresh();
  }

  Future<void> recordPayout({
    required String roundId,
    required String recipientParticipantId,
    required double amount,
    String paymentMethod = 'CASH',
    String? paymentReference,
  }) async {
    final idirId = _idirId;
    final current = state.valueOrNull;
    if (idirId == null || current == null) return;
    await _repo.recordPayout(
      idirId,
      current.id,
      roundId: roundId,
      recipientParticipantId: recipientParticipantId,
      amount: amount,
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
    );
    await refresh();
  }
}

final ikubJoinRequestsProvider =
    FutureProvider.autoDispose<List<IkubJoinRequestModel>>((ref) async {
  final activeIdir = ref.watch(currentActiveIdirProvider);
  final activeIkubState = ref.watch(activeIkubProvider);
  final group = activeIkubState.valueOrNull;
  if (activeIdir == null || group == null) return [];

  final repo = ref.watch(ikubRepositoryProvider);
  return repo.listJoinRequests(activeIdir.id, group.id);
});