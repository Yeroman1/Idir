import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/expenses_repository.dart';
import '../../domain/models/expense.dart';

final expensesCategoryFilterProvider = StateProvider<ExpenseCategory?>((ref) => null);

/// Filtered expenses
final filteredExpensesProvider = Provider<List<Expense>>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  final filter = ref.watch(expensesCategoryFilterProvider);
  final all = expensesAsync.value ?? [];

  if (filter == null) return all;
  return all.where((e) => e.category == filter).toList();
});

/// Computes net expenses (all expenses minus reversals)
final netExpensesTotalProvider = Provider<double>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  final all = expensesAsync.value ?? [];

  double total = 0.0;
  for (final e in all) {
    if (e.isReversal) {
      total -= e.amount;
    } else if (!e.isReversed) {
      total += e.amount;
    }
  }
  return total < 0 ? 0.0 : total;
});

class ExpenseActionNotifier extends StateNotifier<AsyncValue<void>> {
  ExpenseActionNotifier(this._expensesRepo) : super(const AsyncValue.data(null));

  final ExpensesRepository _expensesRepo;

  Future<bool> recordExpense(Expense expense) async {
    state = const AsyncValue.loading();
    try {
      await _expensesRepo.recordExpense(expense);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> reverseExpense({
    required String originalId,
    required String reason,
    required String recordedByUid,
    required String recordedByName,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _expensesRepo.reverseExpense(
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

final expenseActionNotifierProvider =
    StateNotifierProvider<ExpenseActionNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(expensesRepositoryProvider);
  return ExpenseActionNotifier(repo);
});
