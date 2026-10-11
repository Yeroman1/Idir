import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/expenses_repository.dart';
import '../../domain/models/expense.dart';
import '../providers/expenses_provider.dart';

class RecordExpenseDialog extends ConsumerStatefulWidget {
  const RecordExpenseDialog({super.key});

  @override
  ConsumerState<RecordExpenseDialog> createState() =>
      _RecordExpenseDialogState();
}

class _RecordExpenseDialogState extends ConsumerState<RecordExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.administrative;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final currentUser = ref.read(currentUserProvider);

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(expensesRepositoryProvider);
      final voucherNumber = await repo.generateNextVoucherNumber();
      final now = DateTime.now();

      final expense = Expense(
        id: const Uuid().v4(),
        voucherNumber: voucherNumber,
        category: _category,
        amount: double.tryParse(_amountCtrl.text.trim()) ?? 0.0,
        description: _descCtrl.text.trim(),
        recordedByUid: currentUser?.uid ?? 'treasurer',
        recordedByName: currentUser?.name ?? 'Treasurer',
        createdAt: now,
      );

      final success = await ref
          .read(expenseActionNotifierProvider.notifier)
          .recordExpense(expense);

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Expense $voucherNumber recorded successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          navigator.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: AppColors.secondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Record Expense',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Category
                const Text(
                  'Expense Category',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<ExpenseCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ExpenseCategory.administrative,
                      child: Text('Administrative & Stationery'),
                    ),
                    DropdownMenuItem(
                      value: ExpenseCategory.hallRental,
                      child: Text('Hall / Venue Rental'),
                    ),
                    DropdownMenuItem(
                      value: ExpenseCategory.funeralEquipment,
                      child: Text('Tent, Utensils & Equipment'),
                    ),
                    DropdownMenuItem(
                      value: ExpenseCategory.other,
                      child: Text('Other Association Expense'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${l10n.amountLabel} *',
                    prefixIcon: const Icon(Icons.money),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.invalidAmount;
                    final num = double.tryParse(v.trim());
                    if (num == null || num <= 0) return l10n.invalidAmount;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Expense Description *',
                    hintText: 'e.g. Purchased 2 new community ledger binders',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Description is mandatory for audit trail'
                      : null,
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.confirm),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
