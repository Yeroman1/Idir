import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../../../../core/storage/offline_cache_service.dart';
import '../../members/data/members_repository.dart';
import '../domain/models/contribution.dart';
import '../domain/services/balance_calculator_service.dart';
import 'rest_contributions_repository.dart';

abstract class ContributionsRepository {
  Stream<List<Contribution>> watchContributions();
  Future<List<Contribution>> getContributions();
  Future<List<Contribution>> getContributionsByMember(String memberId);
  Future<Contribution?> getContributionById(String id);
  Future<void> recordContribution(Contribution contribution);
  Future<void> reverseContribution({
    required String originalId,
    required String reason,
    required String recordedByUid,
    required String recordedByName,
  });
  Future<String> generateNextReceiptNumber();
}

class FirestoreContributionsRepository implements ContributionsRepository {
  FirestoreContributionsRepository({
    FirebaseFirestore? firestore,
    required MembersRepository membersRepository,
    BalanceCalculatorService balanceCalculator =
        const BalanceCalculatorService(),
  })  : _firestore = firestore,
        _membersRepository = membersRepository,
        _balanceCalculator = balanceCalculator {
    _initLocalDemoSeed();
  }

  final FirebaseFirestore? _firestore;
  final MembersRepository _membersRepository;
  final BalanceCalculatorService _balanceCalculator;

  final List<Contribution> _localCache = [];
  final _streamController = StreamController<List<Contribution>>.broadcast();

  FirebaseFirestore? get _fs {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  void _initLocalDemoSeed() {
    final now = DateTime.now();
    final year = now.year;

    _localCache.addAll([
      Contribution(
        id: 'c_1',
        receiptNumber: 'REC-$year-001',
        memberId: 'MEM-001',
        memberName: 'Abebe Tadesse',
        amount: 50.0,
        date: DateTime(year, now.month, 1, 10, 30),
        recordedByUid: 'demo_treasurer',
        recordedByName: 'Chaltu Bekele (Treasurer)',
        paymentMethod: PaymentMethod.telebirr,
        periodMonth: now.month,
        periodYear: year,
        notes: 'Monthly contribution via Telebirr',
        createdAt: DateTime(year, now.month, 1, 10, 30),
      ),
      Contribution(
        id: 'c_2',
        receiptNumber: 'REC-$year-002',
        memberId: 'MEM-002',
        memberName: 'Chaltu Bekele',
        amount: 50.0,
        date: DateTime(year, now.month, 2, 14, 0),
        recordedByUid: 'demo_treasurer',
        recordedByName: 'Chaltu Bekele (Treasurer)',
        paymentMethod: PaymentMethod.cash,
        periodMonth: now.month,
        periodYear: year,
        notes: 'Paid at monthly gathering',
        createdAt: DateTime(year, now.month, 2, 14, 0),
      ),
      Contribution(
        id: 'c_3',
        receiptNumber: 'REC-$year-003',
        memberId: 'MEM-005',
        memberName: 'Haile Gebrselassie',
        amount: 200.0,
        date: DateTime(year, now.month, 3, 9, 15),
        recordedByUid: 'demo_treasurer',
        recordedByName: 'Chaltu Bekele (Treasurer)',
        paymentMethod: PaymentMethod.cbeBirr,
        periodMonth: now.month,
        periodYear: year,
        notes: 'Prepayment for 4 months',
        createdAt: DateTime(year, now.month, 3, 9, 15),
      ),
      Contribution(
        id: 'c_4',
        receiptNumber: 'REC-$year-004',
        memberId: 'MEM-001',
        memberName: 'Abebe Tadesse',
        amount: 50.0,
        date: DateTime(year, now.month > 1 ? now.month - 1 : 12, 15),
        recordedByUid: 'demo_treasurer',
        recordedByName: 'Chaltu Bekele (Treasurer)',
        paymentMethod: PaymentMethod.telebirr,
        periodMonth: now.month > 1 ? now.month - 1 : 12,
        periodYear: now.month > 1 ? year : year - 1,
        notes: 'Previous month contribution',
        createdAt: DateTime(year, now.month > 1 ? now.month - 1 : 12, 15),
      ),
    ]);
  }

  @override
  Stream<List<Contribution>> watchContributions() async* {
    final fs = _fs;
    if (fs != null) {
      try {
        final stream = fs
            .collection(AppConstants.colContributions)
            .orderBy('date', descending: true)
            .snapshots();

        await for (final snapshot in stream) {
          if (snapshot.docs.isNotEmpty) {
            final list = snapshot.docs
                .map((d) => Contribution.fromMap(d.id, d.data()))
                .toList();
            yield list;
            continue;
          }
          yield List.unmodifiable(_localCache);
        }
        return;
      } catch (e) {
        debugPrint('Firestore watchContributions fallback: $e');
      }
    }

    yield List.unmodifiable(_localCache);
    yield* _streamController.stream;
  }

  @override
  Future<List<Contribution>> getContributions() async {
    final fs = _fs;
    if (fs != null) {
      try {
        final snapshot = await fs
            .collection(AppConstants.colContributions)
            .orderBy('date', descending: true)
            .get();
        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs
              .map((d) => Contribution.fromMap(d.id, d.data()))
              .toList();
        }
      } catch (e) {
        debugPrint('Firestore getContributions fallback: $e');
      }
    }
    return List.unmodifiable(_localCache);
  }

  @override
  Future<List<Contribution>> getContributionsByMember(String memberId) async {
    final all = await getContributions();
    return all.where((c) => c.memberId == memberId).toList();
  }

  @override
  Future<Contribution?> getContributionById(String id) async {
    final fs = _fs;
    if (fs != null) {
      try {
        final doc =
            await fs.collection(AppConstants.colContributions).doc(id).get();
        if (doc.exists && doc.data() != null) {
          return Contribution.fromMap(doc.id, doc.data()!);
        }
      } catch (e) {
        debugPrint('Firestore getContributionById fallback: $e');
      }
    }
    try {
      return _localCache.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> recordContribution(Contribution contribution) async {
    final fs = _fs;
    if (fs != null) {
      try {
        await fs
            .collection(AppConstants.colContributions)
            .doc(contribution.id)
            .set(contribution.toMap());
      } catch (e) {
        debugPrint('Firestore recordContribution fallback: $e');
      }
    }

    _localCache.removeWhere((c) => c.id == contribution.id);
    _localCache.insert(0, contribution);
    _streamController.add(List.unmodifiable(_localCache));

    // Recalculate member's standing and update member record
    await _recalculateMemberBalances(contribution.memberId);
  }

  @override
  Future<void> reverseContribution({
    required String originalId,
    required String reason,
    required String recordedByUid,
    required String recordedByName,
  }) async {
    final original = await getContributionById(originalId);
    if (original == null) throw Exception('Original receipt not found');
    if (original.isReversed) throw Exception('Receipt has already been reversed');

    final updatedOriginal = original.copyWith(isReversed: true);
    final reversalId = const Uuid().v4();
    final now = DateTime.now();
    final year = now.year;

    final reversalContribution = Contribution(
      id: reversalId,
      receiptNumber: 'REV-$year-${original.receiptNumber.replaceAll('REC-$year-', '')}',
      memberId: original.memberId,
      memberName: original.memberName,
      amount: original.amount,
      date: now,
      recordedByUid: recordedByUid,
      recordedByName: recordedByName,
      paymentMethod: original.paymentMethod,
      periodMonth: original.periodMonth,
      periodYear: original.periodYear,
      notes: reason,
      isReversal: true,
      reversalOfId: originalId,
      reversalReason: reason,
      isReversed: false,
      createdAt: now,
    );

    final fs = _fs;
    if (fs != null) {
      try {
        final batch = fs.batch();
        batch.update(
          fs.collection(AppConstants.colContributions).doc(original.id),
          {'isReversed': true},
        );
        batch.set(
          fs.collection(AppConstants.colContributions).doc(reversalId),
          reversalContribution.toMap(),
        );
        await batch.commit();
      } catch (e) {
        debugPrint('Firestore reverseContribution batch fallback: $e');
      }
    }

    final origIndex = _localCache.indexWhere((c) => c.id == original.id);
    if (origIndex != -1) {
      _localCache[origIndex] = updatedOriginal;
    }
    _localCache.insert(0, reversalContribution);
    _streamController.add(List.unmodifiable(_localCache));

    // Recalculate member balances after reversal
    await _recalculateMemberBalances(original.memberId);
  }

  Future<void> _recalculateMemberBalances(String memberId) async {
    final member = await _membersRepository.getMemberById(memberId);
    if (member == null) return;

    final memberHistory = await getContributionsByMember(memberId);
    final summary = _balanceCalculator.calculateSummary(
      member: member,
      memberContributions: memberHistory,
    );

    final updatedMember = member.copyWith(
      totalPaid: summary.totalPaid,
      balance: summary.balance,
      arrears: summary.arrears,
      updatedAt: DateTime.now(),
    );

    await _membersRepository.updateMember(updatedMember);
  }

  @override
  Future<String> generateNextReceiptNumber() async {
    final year = DateTime.now().year;
    final all = await getContributions();
    int highest = 0;
    for (final c in all) {
      if (c.receiptNumber.startsWith('REC-$year-')) {
        final numPart = int.tryParse(
          c.receiptNumber.replaceFirst('REC-$year-', ''),
        );
        if (numPart != null && numPart > highest) {
          highest = numPart;
        }
      }
    }
    final next = highest + 1;
    return 'REC-$year-${next.toString().padLeft(3, '0')}';
  }
}

final balanceCalculatorServiceProvider = Provider<BalanceCalculatorService>((ref) {
  return const BalanceCalculatorService();
});

final contributionsRepositoryProvider =
    Provider<ContributionsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  final membersRepo = ref.watch(membersRepositoryProvider);
  final calc = ref.watch(balanceCalculatorServiceProvider);
  final activeIdirId =
      ref.watch(activeIdirIdProvider) ?? AppConstants.defaultIdirId;
  return RestContributionsRepository(
    apiClient: apiClient,
    cacheService: cache,
    ref: ref,
    membersRepository: membersRepo,
    balanceCalculator: calc,
    idirId: activeIdirId,
  );
});
