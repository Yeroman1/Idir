import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/contributions_repository.dart';
import '../../domain/models/contribution.dart';

final contributionsStreamProvider = StreamProvider<List<Contribution>>((ref) async* {
  final repo = ref.watch(contributionsRepositoryProvider);
  repo.getContributions();
  yield* repo.watchContributions();
});

final contributionSearchQueryProvider = StateProvider<String>((ref) => '');

final contributionMethodFilterProvider =
    StateProvider<PaymentMethod?>((ref) => null);

final contributionMonthFilterProvider = StateProvider<int?>((ref) => null);

final filteredContributionsProvider = Provider<List<Contribution>>((ref) {
  final listAsync = ref.watch(contributionsStreamProvider);
  final all = listAsync.valueOrNull ?? [];
  final user = ref.watch(currentUserProvider);

  final query =
      ref.watch(contributionSearchQueryProvider).trim().toLowerCase();
  final methodFilter = ref.watch(contributionMethodFilterProvider);
  final monthFilter = ref.watch(contributionMonthFilterProvider);

  return all.where((c) {
    // If logged-in user is a regular member, only show their own contributions
    if (user != null && user.role == UserRole.member) {
      if (c.memberId != user.memberId) return false;
    }

    if (methodFilter != null && c.paymentMethod != methodFilter) {
      return false;
    }

    if (monthFilter != null && c.periodMonth != monthFilter) {
      return false;
    }

    if (query.isNotEmpty) {
      final matchReceipt = c.receiptNumber.toLowerCase().contains(query);
      final matchMember = c.memberName.toLowerCase().contains(query);
      final matchMemberId = c.memberId.toLowerCase().contains(query);
      if (!matchReceipt && !matchMember && !matchMemberId) return false;
    }

    return true;
  }).toList();
});

class ContributionStats {
  const ContributionStats({
    required this.thisMonthTotal,
    required this.allTimeTotal,
    required this.thisMonthCount,
    required this.allTimeCount,
  });

  final double thisMonthTotal;
  final double allTimeTotal;
  final int thisMonthCount;
  final int allTimeCount;
}

final contributionStatsProvider = Provider<ContributionStats>((ref) {
  final listAsync = ref.watch(contributionsStreamProvider);
  final all = listAsync.valueOrNull ?? [];
  final now = DateTime.now();

  double thisMonthTotal = 0;
  double allTimeTotal = 0;
  int thisMonthCount = 0;
  int allTimeCount = 0;

  for (final c in all) {
    // Reversals subtract or are offset
    final netAmount = c.isReversal ? -c.amount : (!c.isReversed ? c.amount : 0.0);

    allTimeTotal += netAmount;
    allTimeCount++;

    if (c.date.year == now.year && c.date.month == now.month) {
      thisMonthTotal += netAmount;
      thisMonthCount++;
    }
  }

  return ContributionStats(
    thisMonthTotal: thisMonthTotal < 0 ? 0 : thisMonthTotal,
    allTimeTotal: allTimeTotal < 0 ? 0 : allTimeTotal,
    thisMonthCount: thisMonthCount,
    allTimeCount: allTimeCount,
  );
});

class ContributionActionNotifier extends StateNotifier<AsyncValue<void>> {
  ContributionActionNotifier(this._repo) : super(const AsyncValue.data(null));

  final ContributionsRepository _repo;

  Future<bool> recordPayment(Contribution contribution) async {
    state = const AsyncValue.loading();
    try {
      await _repo.recordContribution(contribution);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> reversePayment({
    required String originalId,
    required String reason,
    required String recordedByUid,
    required String recordedByName,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.reverseContribution(
        originalId: originalId,
        reason: reason,
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

final contributionActionNotifierProvider =
    StateNotifierProvider<ContributionActionNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(contributionsRepositoryProvider);
  return ContributionActionNotifier(repo);
});
