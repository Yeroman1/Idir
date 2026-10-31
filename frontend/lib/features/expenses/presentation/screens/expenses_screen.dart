import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/expenses_repository.dart';
import '../../domain/models/expense.dart';
import '../providers/expenses_provider.dart';
import 'record_expense_dialog.dart';
import '../../../../core/widgets/offline_indicator_bar.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  void _showReversalDialog(BuildContext context, WidgetRef ref, Expense expense) async {
    final l10n = AppLocalizations.of(context);
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reverse Expense Voucher'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to reverse ${expense.voucherNumber} (${expense.amount.toStringAsFixed(0)} ETB)? This creates an offsetting audit record.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reversal Reason *',
                  hintText: 'e.g. Duplicate entry or erroneous invoice',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Reversal reason is mandatory for audit trail'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final currentUser = ref.read(currentUserProvider);

      final success = await ref
          .read(expenseActionNotifierProvider.notifier)
          .reverseExpense(
            originalId: expense.id,
            reason: reasonCtrl.text.trim(),
            recordedByUid: currentUser?.uid ?? 'treasurer',
            recordedByName: currentUser?.name ?? 'Treasurer',
          );

      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Expense voucher reversed successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _showExpenseDetailDialog(BuildContext context, Expense expense) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(expense.createdAt);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(expense.voucherNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Category', expense.category.name.toUpperCase()),
              _detailRow('Amount', '${expense.amount.toStringAsFixed(2)} ETB'),
              _detailRow('Description', expense.description),
              if (expense.recipient != null && expense.recipient!.isNotEmpty)
                _detailRow('Recipient', expense.recipient!),
              if (expense.reference != null && expense.reference!.isNotEmpty)
                _detailRow('Reference', expense.reference!),
              _detailRow(
                'Status',
                expense.isReversed
                    ? 'REVERSED'
                    : (expense.isVerified ? 'VERIFIED' : 'RECORDED (PENDING)'),
              ),
              _detailRow('Recorded By', expense.recordedByName),
              _detailRow('Date', dateStr),
              if (expense.reversalReason != null && expense.reversalReason!.isNotEmpty)
                _detailRow('Reversal Reason', expense.reversalReason!),
              const SizedBox(height: 12),
              if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 6),
                const Text(
                  'Attached Receipt / Document Proof',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.description_outlined, size: 36, color: AppColors.primary),
                      const SizedBox(height: 6),
                      Text(
                        expense.receiptUrl!,
                        style: const TextStyle(fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Secure receipt attached and auditable',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final expenses = ref.watch(filteredExpensesProvider);
    final netTotal = ref.watch(netExpensesTotalProvider);
    final currentFilter = ref.watch(expensesCategoryFilterProvider);

    final canRecord = user?.role == UserRole.treasurer;
    final currencyFormat = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenses),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              await ref.read(expensesRepositoryProvider).getExpenses();
            },
          ),
        ],
      ),
      floatingActionButton: canRecord
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const RecordExpenseDialog(),
                );
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('Record Expense'),
            )
          : null,
      bottomNavigationBar: const OfflineIndicatorBar(includeBottomSafeArea: true),
      body: Column(
        children: [
          // ── Summary Card ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF5D4037), // Warm earthen brown
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Association Expenses',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ETB ${currencyFormat.format(netTotal)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.outbox, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),

          // ── Category Filter Chips ────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: Text(l10n.filterAll),
                  selected: currentFilter == null,
                  onSelected: (_) {
                    ref.read(expensesCategoryFilterProvider.notifier).state = null;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Payouts'),
                  selected: currentFilter == ExpenseCategory.payout,
                  onSelected: (_) {
                    ref.read(expensesCategoryFilterProvider.notifier).state =
                        ExpenseCategory.payout;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Administrative'),
                  selected: currentFilter == ExpenseCategory.administrative,
                  onSelected: (_) {
                    ref.read(expensesCategoryFilterProvider.notifier).state =
                        ExpenseCategory.administrative;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Hall Rental'),
                  selected: currentFilter == ExpenseCategory.hallRental,
                  onSelected: (_) {
                    ref.read(expensesCategoryFilterProvider.notifier).state =
                        ExpenseCategory.hallRental;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Equipment'),
                  selected: currentFilter == ExpenseCategory.funeralEquipment,
                  onSelected: (_) {
                    ref.read(expensesCategoryFilterProvider.notifier).state =
                        ExpenseCategory.funeralEquipment;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Other'),
                  selected: currentFilter == ExpenseCategory.other,
                  onSelected: (_) {
                    ref.read(expensesCategoryFilterProvider.notifier).state =
                        ExpenseCategory.other;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Expenses List ────────────────────────────────────────────────
          Expanded(
            child: expenses.isEmpty
                ? Center(
                    child: Text(
                      l10n.emptyState,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final exp = expenses[index];
                      final dateStr =
                          DateFormat('dd MMM yyyy').format(exp.createdAt);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _showExpenseDetailDialog(context, exp),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: exp.isReversal
                                                ? AppColors.error.withValues(alpha: 0.12)
                                                : Colors.brown.withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            exp.voucherNumber,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: exp.isReversal
                                                  ? AppColors.error
                                                  : Colors.brown.shade800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            exp.category.name.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: exp.isReversed
                                                ? AppColors.error.withValues(alpha: 0.12)
                                                : (exp.isVerified
                                                    ? AppColors.success.withValues(alpha: 0.12)
                                                    : Colors.amber.withValues(alpha: 0.15)),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            exp.isReversed
                                                ? 'REVERSED'
                                                : (exp.isVerified ? 'VERIFIED' : 'RECORDED'),
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                              color: exp.isReversed
                                                  ? AppColors.error
                                                  : (exp.isVerified
                                                      ? AppColors.success
                                                      : Colors.amber.shade900),
                                            ),
                                          ),
                                        ),
                                        if (exp.receiptUrl != null && exp.receiptUrl!.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.attachment, size: 14, color: AppColors.primary),
                                        ],
                                      ],
                                    ),
                                  Text(
                                    exp.isReversal
                                        ? '+${exp.amount.toStringAsFixed(0)} ETB (Reversal)'
                                        : '-${exp.amount.toStringAsFixed(0)} ETB',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: exp.isReversed
                                          ? Colors.grey
                                          : (exp.isReversal
                                              ? AppColors.success
                                              : AppColors.error),
                                      decoration: exp.isReversed
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                exp.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${exp.recordedByName} • $dateStr',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (canRecord &&
                                      !exp.isReversed &&
                                      !exp.isReversal)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.undo, size: 14),
                                      label: const Text(
                                        'Reverse',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      onPressed: () => _showReversalDialog(
                                          context, ref, exp),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
