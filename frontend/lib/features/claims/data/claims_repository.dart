import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/active_idir_provider.dart';
import '../../../core/storage/offline_cache_service.dart';
import '../../expenses/data/expenses_repository.dart';
import '../../expenses/domain/models/expense.dart';
import '../../members/data/members_repository.dart';
import '../../members/domain/models/member.dart';
import '../domain/models/claim.dart';
import 'rest_claims_repository.dart';

abstract class ClaimsRepository {
  Stream<List<Claim>> watchClaims();
  Future<List<Claim>> getClaims();
  Future<Claim?> getClaimById(String id);
  Future<void> submitClaim(Claim claim);
  Future<Claim> voteOnClaim({
    required String claimId,
    required String uid,
    required String name,
    required String role,
    required String decision, // 'approved' | 'rejected'
    required String comment,
    int approvalsRequired = AppConstants.defaultClaimApprovalsRequired,
  });
  Future<void> recordPayout({
    required String claimId,
    required double payoutAmount,
    required String recordedByUid,
    required String recordedByName,
  });
  Future<String> generateNextClaimNumber();
}

class FirestoreClaimsRepository implements ClaimsRepository {
  FirestoreClaimsRepository({
    FirebaseFirestore? firestore,
    required ExpensesRepository expensesRepository,
    required MembersRepository membersRepository,
  })  : _fs = firestore,
        _expensesRepository = expensesRepository,
        _membersRepository = membersRepository {
    _initLocalCache();
  }

  final FirebaseFirestore? _fs;
  final ExpensesRepository _expensesRepository;
  final MembersRepository _membersRepository;
  final List<Claim> _localCache = [];
  final _streamController = StreamController<List<Claim>>.broadcast();

  void _initLocalCache() {
    final now = DateTime.now();
    final year = now.year;

    _localCache.addAll([
      Claim(
        id: 'clm_001',
        claimNumber: 'CLM-$year-001',
        memberId: 'MEM-002',
        memberName: 'Fatuma Mohammed',
        type: ClaimType.funeral,
        description: 'Condolence and funeral burial support for covered dependent parent',
        requestedAmount: 3000.0,
        status: ClaimStatus.submitted,
        submittedBy: 'demo_member_2',
        submittedByName: 'Fatuma Mohammed',
        approvals: const [],
        createdAt: now.subtract(const Duration(hours: 18)),
      ),
      Claim(
        id: 'clm_002',
        claimNumber: 'CLM-$year-002',
        memberId: 'MEM-001',
        memberName: 'Abebe Tadesse',
        type: ClaimType.illness,
        description: 'Emergency emergency surgical hospitalization support',
        requestedAmount: 1500.0,
        status: ClaimStatus.paid,
        submittedBy: 'demo_member_1',
        submittedByName: 'Abebe Tadesse',
        approvals: [
          ClaimApproval(
            uid: 'demo_chair',
            name: 'Abebe Bikila (Chairperson)',
            role: 'chairperson',
            decision: 'approved',
            comment: 'Verified hospital documents and family relationship.',
            at: now.subtract(const Duration(days: 4)),
          ),
          ClaimApproval(
            uid: 'demo_treasurer',
            name: 'Chaltu Bekele (Treasurer)',
            role: 'treasurer',
            decision: 'approved',
            comment: 'Member is in good financial standing. Approved.',
            at: now.subtract(const Duration(days: 3)),
          ),
        ],
        payoutAmount: 1500.0,
        paidAt: now.subtract(const Duration(days: 2)),
        payoutExpenseId: 'exp_002',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ]);
  }

  @override
  Stream<List<Claim>> watchClaims() async* {
    final fs = _fs;
    if (fs != null) {
      try {
        final stream = fs
            .collection(AppConstants.colClaims)
            .orderBy('createdAt', descending: true)
            .snapshots();

        await for (final snapshot in stream) {
          if (snapshot.docs.isNotEmpty) {
            final list = snapshot.docs
                .map((d) => Claim.fromMap(d.id, d.data()))
                .toList();
            yield list;
            continue;
          }
          yield List.unmodifiable(_localCache);
        }
        return;
      } catch (e) {
        debugPrint('Firestore watchClaims fallback: $e');
      }
    }

    yield List.unmodifiable(_localCache);
    yield* _streamController.stream;
  }

  @override
  Future<List<Claim>> getClaims() async {
    final fs = _fs;
    if (fs != null) {
      try {
        final snapshot = await fs
            .collection(AppConstants.colClaims)
            .orderBy('createdAt', descending: true)
            .get();
        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs
              .map((d) => Claim.fromMap(d.id, d.data()))
              .toList();
        }
      } catch (e) {
        debugPrint('Firestore getClaims fallback: $e');
      }
    }
    return List.unmodifiable(_localCache);
  }

  @override
  Future<Claim?> getClaimById(String id) async {
    final all = await getClaims();
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> submitClaim(Claim claim) async {
    // Check member eligibility: inactive/suspended members cannot claim
    final member = await _membersRepository.getMemberById(claim.memberId);
    if (member != null && member.status != MemberStatus.active) {
      throw Exception('Inactive or suspended members cannot submit claims');
    }

    final fs = _fs;
    if (fs != null) {
      try {
        await fs
            .collection(AppConstants.colClaims)
            .doc(claim.id)
            .set(claim.toMap());
      } catch (e) {
        debugPrint('Firestore submitClaim fallback: $e');
      }
    }

    _localCache.removeWhere((c) => c.id == claim.id);
    _localCache.insert(0, claim);
    _streamController.add(List.unmodifiable(_localCache));
  }

  @override
  Future<Claim> voteOnClaim({
    required String claimId,
    required String uid,
    required String name,
    required String role,
    required String decision,
    required String comment,
    int approvalsRequired = AppConstants.defaultClaimApprovalsRequired,
  }) async {
    final claim = await getClaimById(claimId);
    if (claim == null) throw Exception('Claim not found');

    // Rule 4: A person cannot approve their own claim (Self-approval prevention)
    if (claim.submittedBy == uid) {
      throw Exception('Self-approval prevention: You cannot vote on a claim you submitted');
    }

    // Prevent duplicate vote by the same officer
    if (claim.hasVoted(uid)) {
      throw Exception('You have already cast your vote on this claim');
    }

    if (claim.status != ClaimStatus.submitted) {
      throw Exception('Only submitted claims can be voted on');
    }

    final newApproval = ClaimApproval(
      uid: uid,
      name: name,
      role: role,
      decision: decision,
      comment: comment,
      at: DateTime.now(),
    );

    final updatedApprovals = [...claim.approvals, newApproval];
    ClaimStatus newStatus = ClaimStatus.submitted;

    if (decision == 'rejected') {
      newStatus = ClaimStatus.rejected;
    } else {
      final approvedCount =
          updatedApprovals.where((a) => a.decision == 'approved').length;
      if (approvedCount >= approvalsRequired) {
        newStatus = ClaimStatus.approved;
      }
    }

    final updatedClaim = claim.copyWith(
      approvals: updatedApprovals,
      status: newStatus,
    );

    final fs = _fs;
    if (fs != null) {
      try {
        await fs
            .collection(AppConstants.colClaims)
            .doc(claim.id)
            .update(updatedClaim.toMap());
      } catch (e) {
        debugPrint('Firestore voteOnClaim fallback: $e');
      }
    }

    final index = _localCache.indexWhere((c) => c.id == claim.id);
    if (index != -1) {
      _localCache[index] = updatedClaim;
    }
    _streamController.add(List.unmodifiable(_localCache));

    return updatedClaim;
  }

  @override
  Future<void> recordPayout({
    required String claimId,
    required double payoutAmount,
    required String recordedByUid,
    required String recordedByName,
  }) async {
    final claim = await getClaimById(claimId);
    if (claim == null) throw Exception('Claim not found');
    if (claim.status != ClaimStatus.approved) {
      throw Exception('Only approved claims can be disbursed for payout');
    }

    final voucherNumber = await _expensesRepository.generateNextVoucherNumber();
    final expenseId = const Uuid().v4();
    final now = DateTime.now();

    final expense = Expense(
      id: expenseId,
      voucherNumber: voucherNumber,
      category: ExpenseCategory.payout,
      amount: payoutAmount,
      description:
          'Approved mutual-aid payout for ${claim.memberName} (${claim.claimNumber})',
      claimId: claim.id,
      recordedByUid: recordedByUid,
      recordedByName: recordedByName,
      createdAt: now,
    );

    // 1. Record payout expense in expenses ledger
    await _expensesRepository.recordExpense(expense);

    // 2. Mark claim as paid
    final updatedClaim = claim.copyWith(
      status: ClaimStatus.paid,
      payoutAmount: payoutAmount,
      paidAt: now,
      payoutExpenseId: expenseId,
    );

    final fs = _fs;
    if (fs != null) {
      try {
        await fs
            .collection(AppConstants.colClaims)
            .doc(claim.id)
            .update(updatedClaim.toMap());
      } catch (e) {
        debugPrint('Firestore recordPayout fallback: $e');
      }
    }

    final index = _localCache.indexWhere((c) => c.id == claim.id);
    if (index != -1) {
      _localCache[index] = updatedClaim;
    }
    _streamController.add(List.unmodifiable(_localCache));
  }

  @override
  Future<String> generateNextClaimNumber() async {
    final year = DateTime.now().year;
    final all = await getClaims();
    int highest = 0;
    for (final c in all) {
      if (c.claimNumber.startsWith('CLM-$year-')) {
        final numPart = int.tryParse(
          c.claimNumber.replaceFirst('CLM-$year-', ''),
        );
        if (numPart != null && numPart > highest) {
          highest = numPart;
        }
      }
    }
    final next = highest + 1;
    return 'CLM-$year-${next.toString().padLeft(3, '0')}';
  }
}

final claimsRepositoryProvider = Provider<ClaimsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  final activeIdirId =
      ref.watch(activeIdirIdProvider) ?? AppConstants.defaultIdirId;
  return RestClaimsRepository(
    apiClient: apiClient,
    cacheService: cache,
    ref: ref,
    idirId: activeIdirId,
  );
});

final claimsStreamProvider = StreamProvider<List<Claim>>((ref) {
  final repo = ref.watch(claimsRepositoryProvider);
  return repo.watchClaims();
});
