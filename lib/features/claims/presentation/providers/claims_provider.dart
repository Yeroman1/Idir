import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/claims_repository.dart';
import '../../domain/models/claim.dart';

final claimsFilterProvider = StateProvider<ClaimStatus?>((ref) => null);
final claimsSearchQueryProvider = StateProvider<String>((ref) => '');

/// Streams claims filtered by institutional role (members only see their own)
final visibleClaimsProvider = Provider<List<Claim>>((ref) {
  final claimsAsync = ref.watch(claimsStreamProvider);
  final user = ref.watch(currentUserProvider);
  final all = claimsAsync.value ?? [];

  if (user == null) return [];

  // Regular members can only view their own claims
  if (user.role == UserRole.member) {
    return all.where((c) => c.memberId == user.memberId).toList();
  }

  // Chairperson, Treasurer, Auditor can view all claims
  return all;
});

/// Applies status filters and live search text
final filteredClaimsProvider = Provider<List<Claim>>((ref) {
  final claims = ref.watch(visibleClaimsProvider);
  final filter = ref.watch(claimsFilterProvider);
  final query = ref.watch(claimsSearchQueryProvider).trim().toLowerCase();

  return claims.where((c) {
    if (filter != null && c.status != filter) {
      return false;
    }
    if (query.isNotEmpty) {
      final matchesName = c.memberName.toLowerCase().contains(query);
      final matchesNum = c.claimNumber.toLowerCase().contains(query);
      final matchesDesc = c.description.toLowerCase().contains(query);
      final matchesMemberId = c.memberId.toLowerCase().contains(query);
      return matchesName || matchesNum || matchesDesc || matchesMemberId;
    }
    return true;
  }).toList();
});

class ClaimActionNotifier extends StateNotifier<AsyncValue<void>> {
  ClaimActionNotifier(this._claimsRepo) : super(const AsyncValue.data(null));

  final ClaimsRepository _claimsRepo;

  Future<bool> submitClaim(Claim claim) async {
    state = const AsyncValue.loading();
    try {
      await _claimsRepo.submitClaim(claim);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> voteOnClaim({
    required String claimId,
    required String uid,
    required String name,
    required String role,
    required String decision,
    required String comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _claimsRepo.voteOnClaim(
        claimId: claimId,
        uid: uid,
        name: name,
        role: role,
        decision: decision,
        comment: comment,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> recordPayout({
    required String claimId,
    required double payoutAmount,
    required String recordedByUid,
    required String recordedByName,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _claimsRepo.recordPayout(
        claimId: claimId,
        payoutAmount: payoutAmount,
        recordedByUid: recordedByUid,
        recordedByName: recordedByName,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final claimActionNotifierProvider =
    StateNotifierProvider<ClaimActionNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(claimsRepositoryProvider);
  return ClaimActionNotifier(repo);
});
