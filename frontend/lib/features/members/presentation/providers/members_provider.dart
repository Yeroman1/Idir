import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/member.dart';
import '../../data/members_repository.dart';

final membersStreamProvider = StreamProvider<List<Member>>((ref) async* {
  final repo = ref.watch(membersRepositoryProvider);
  repo.getMembers();
  yield* repo.watchMembers();
});

final memberSearchQueryProvider = StateProvider<String>((ref) => '');

final memberStatusFilterProvider =
    StateProvider<MemberStatus?>((ref) => null);

final filteredMembersProvider = Provider<List<Member>>((ref) {
  final membersAsync = ref.watch(membersStreamProvider);
  final members = membersAsync.valueOrNull ?? [];
  final query = ref.watch(memberSearchQueryProvider).trim().toLowerCase();
  final statusFilter = ref.watch(memberStatusFilterProvider);

  return members.where((m) {
    if (statusFilter != null && m.status != statusFilter) {
      return false;
    }
    if (query.isNotEmpty) {
      final matchName = m.fullName.toLowerCase().contains(query);
      final matchId = m.memberId.toLowerCase().contains(query);
      final matchPhone = m.phone.toLowerCase().contains(query);
      if (!matchName && !matchId && !matchPhone) return false;
    }
    return true;
  }).toList();
});

final memberDetailProvider =
    FutureProvider.family<Member?, String>((ref, id) async {
  final repo = ref.watch(membersRepositoryProvider);
  return repo.getMemberById(id);
});

class MemberActionNotifier extends StateNotifier<AsyncValue<void>> {
  MemberActionNotifier(this._repo) : super(const AsyncValue.data(null));

  final MembersRepository _repo;

  Future<bool> createMember(Member member) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addMember(member);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateMember(Member member) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateMember(member);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> toggleMemberStatus(Member member) async {
    final newStatus = member.status == MemberStatus.active
        ? MemberStatus.suspended
        : MemberStatus.active;
    final updated = member.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
    return updateMember(updated);
  }

  Future<bool> deleteMember(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteMember(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final memberActionNotifierProvider =
    StateNotifierProvider<MemberActionNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(membersRepositoryProvider);
  return MemberActionNotifier(repo);
});
