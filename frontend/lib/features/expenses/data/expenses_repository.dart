import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/active_idir_provider.dart';
import '../../../core/storage/offline_cache_service.dart';
import '../domain/models/expense.dart';
import 'rest_expenses_repository.dart';

abstract class ExpensesRepository {
  Stream<List<Expense>> watchExpenses();
  Future<List<Expense>> getExpenses();
  Future<Expense?> getExpenseById(String id);
  Future<void> recordExpense(Expense expense);
  Future<void> reverseExpense({
    required String originalId,
    required String reason,
    required String recordedByUid,
    required String recordedByName,
  });
  Future<String> generateNextVoucherNumber();
}

class FirestoreExpensesRepository implements ExpensesRepository {
  FirestoreExpensesRepository({FirebaseFirestore? firestore})
      : _fs = firestore {
    _initLocalCache();
  }

  final FirebaseFirestore? _fs;
  final List<Expense> _localCache = [];
  final _streamController = StreamController<List<Expense>>.broadcast();

  void _initLocalCache() {
    final now = DateTime.now();
    final year = now.year;

    _localCache.addAll([
      Expense(
        id: 'exp_001',
        voucherNumber: 'EXP-$year-001',
        category: ExpenseCategory.funeralEquipment,
        amount: 850.0,
        description: 'Community tent and chairs repair & maintenance',
        recordedByUid: 'demo_treasurer',
        recordedByName: 'Chaltu Bekele (Treasurer)',
        createdAt: DateTime(year, now.month, 5),
      ),
      Expense(
        id: 'exp_002',
        voucherNumber: 'EXP-$year-002',
        category: ExpenseCategory.administrative,
        amount: 300.0,
        description: 'Ledger books, stationery & printed receipt stamps',
        recordedByUid: 'demo_treasurer',
        recordedByName: 'Chaltu Bekele (Treasurer)',
        createdAt: DateTime(year, now.month, 10),
      ),
    ]);
  }

  @override
  Stream<List<Expense>> watchExpenses() async* {
    final fs = _fs;
    if (fs != null) {
      try {
        final stream = fs
            .collection(AppConstants.colExpenses)
            .orderBy('createdAt', descending: true)
            .snapshots();

        await for (final snapshot in stream) {
          if (snapshot.docs.isNotEmpty) {
            final list = snapshot.docs
                .map((d) => Expense.fromMap(d.id, d.data()))
                .toList();
            yield list;
            continue;
          }
          yield List.unmodifiable(_localCache);
        }
        return;
      } catch (e) {
        debugPrint('Firestore watchExpenses fallback: $e');
      }
    }

    yield List.unmodifiable(_localCache);
    yield* _streamController.stream;
  }

  @override
  Future<List<Expense>> getExpenses() async {
    final fs = _fs;
    if (fs != null) {
      try {
        final snapshot = await fs
            .collection(AppConstants.colExpenses)
            .orderBy('createdAt', descending: true)
            .get();
        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs
              .map((d) => Expense.fromMap(d.id, d.data()))
              .toList();
        }
      } catch (e) {
        debugPrint('Firestore getExpenses fallback: $e');
      }
    }
    return List.unmodifiable(_localCache);
  }

  @override
  Future<Expense?> getExpenseById(String id) async {
    final all = await getExpenses();
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> recordExpense(Expense expense) async {
    final fs = _fs;
    if (fs != null) {
      try {
        await fs
            .collection(AppConstants.colExpenses)
            .doc(expense.id)
            .set(expense.toMap());
      } catch (e) {
        debugPrint('Firestore recordExpense fallback: $e');
      }
    }

    _localCache.removeWhere((e) => e.id == expense.id);
    _localCache.insert(0, expense);
    _streamController.add(List.unmodifiable(_localCache));
  }

  @override
  Future<void> reverseExpense({
    required String originalId,
    required String reason,
    required String recordedByUid,
    required String recordedByName,
  }) async {
    final original = await getExpenseById(originalId);
    if (original == null) throw Exception('Original expense voucher not found');
    if (original.isReversed) throw Exception('Expense has already been reversed');

    final updatedOriginal = original.copyWith(isReversed: true);
    final reversalId = const Uuid().v4();
    final now = DateTime.now();
    final year = now.year;

    final reversalExpense = Expense(
      id: reversalId,
      voucherNumber:
          'REV-$year-${original.voucherNumber.replaceAll('EXP-$year-', '')}',
      category: original.category,
      amount: original.amount,
      description: 'Reversal: $reason',
      claimId: original.claimId,
      isReversal: true,
      reversalOfId: originalId,
      reversalReason: reason,
      isReversed: false,
      recordedByUid: recordedByUid,
      recordedByName: recordedByName,
      createdAt: now,
    );

    final fs = _fs;
    if (fs != null) {
      try {
        final batch = fs.batch();
        batch.update(
          fs.collection(AppConstants.colExpenses).doc(original.id),
          {'isReversed': true},
        );
        batch.set(
          fs.collection(AppConstants.colExpenses).doc(reversalId),
          reversalExpense.toMap(),
        );
        await batch.commit();
      } catch (e) {
        debugPrint('Firestore reverseExpense fallback: $e');
      }
    }

    final origIndex = _localCache.indexWhere((e) => e.id == original.id);
    if (origIndex != -1) {
      _localCache[origIndex] = updatedOriginal;
    }
    _localCache.insert(0, reversalExpense);
    _streamController.add(List.unmodifiable(_localCache));
  }

  @override
  Future<String> generateNextVoucherNumber() async {
    final year = DateTime.now().year;
    final all = await getExpenses();
    int highest = 0;
    for (final e in all) {
      if (e.voucherNumber.startsWith('EXP-$year-')) {
        final numPart = int.tryParse(
          e.voucherNumber.replaceFirst('EXP-$year-', ''),
        );
        if (numPart != null && numPart > highest) {
          highest = numPart;
        }
      }
    }
    final next = highest + 1;
    return 'EXP-$year-${next.toString().padLeft(3, '0')}';
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  final activeIdirId =
      ref.watch(activeIdirIdProvider) ?? AppConstants.defaultIdirId;
  return RestExpensesRepository(
    apiClient: apiClient,
    cacheService: cache,
    ref: ref,
    idirId: activeIdirId,
  );
});

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) async* {
  final repo = ref.watch(expensesRepositoryProvider);
  repo.getExpenses();
  yield* repo.watchExpenses();
});
