import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../members/domain/models/member.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../data/contributions_repository.dart';
import '../../domain/models/contribution.dart';
import '../providers/contributions_provider.dart';

class RecordContributionDialog extends ConsumerStatefulWidget {
  const RecordContributionDialog({
    super.key,
    this.preselectedMemberId,
  });

  final String? preselectedMemberId;

  @override
  ConsumerState<RecordContributionDialog> createState() =>
      _RecordContributionDialogState();
}

class _RecordContributionDialogState
    extends ConsumerState<RecordContributionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController(text: '50');
  final _notesCtrl = TextEditingController();

  Member? _selectedMember;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _receiptNumber = '';
  bool _isLoading = false;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _initData();
      _isInit = true;
    }
  }

  Future<void> _initData() async {
    final repo = ref.read(contributionsRepositoryProvider);
    final receiptNum = await repo.generateNextReceiptNumber();
    if (mounted) {
      setState(() => _receiptNumber = receiptNum);
    }

    final members = ref.read(membersStreamProvider).valueOrNull ?? [];
    if (widget.preselectedMemberId != null && members.isNotEmpty) {
      final found = members.where((m) => m.id == widget.preselectedMemberId).firstOrNull;
      if (found != null && mounted) {
        setState(() {
          _selectedMember = found;
          _amountCtrl.text = found.monthlyDues.toStringAsFixed(0);
        });
      }
    } else if (members.isNotEmpty && _selectedMember == null) {
      setState(() {
        _selectedMember = members.first;
        _amountCtrl.text = members.first.monthlyDues.toStringAsFixed(0);
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMember == null) return;

    setState(() => _isLoading = true);

    final l10n = AppLocalizations.of(context);
    final currentUser = ref.read(currentUserProvider);
    final now = DateTime.now();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 50.0;

    final contribution = Contribution(
      id: const Uuid().v4(),
      receiptNumber: _receiptNumber.isNotEmpty
          ? _receiptNumber
          : 'REC-$_selectedYear-${now.millisecondsSinceEpoch % 1000}',
      memberId: _selectedMember!.memberId,
      memberName: _selectedMember!.fullName,
      amount: amount,
      date: now,
      recordedByUid: currentUser?.uid ?? 'treasurer',
      recordedByName: currentUser?.name ?? 'Treasurer',
      paymentMethod: _paymentMethod,
      periodMonth: _selectedMonth,
      periodYear: _selectedYear,
      notes: _notesCtrl.text.trim(),
      createdAt: now,
    );

    final actionNotifier =
        ref.read(contributionActionNotifierProvider.notifier);
    final success = await actionNotifier.recordPayment(contribution);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.contributionRecordedSuccess} (${contribution.receiptNumber})',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final members = ref.watch(membersStreamProvider).valueOrNull ?? [];

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.recordPayment,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_receiptNumber.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _receiptNumber,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Member Selection
                Text(l10n.selectMember,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<Member>(
                  initialValue: _selectedMember,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: members.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(
                        '${m.fullName} (${m.memberId})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedMember = val;
                        _amountCtrl.text = val.monthlyDues.toStringAsFixed(0);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Amount
                Text(l10n.amountLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: l10n.currency,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.invalidAmount;
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return l10n.invalidAmount;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Period (Month & Year)
                Text(l10n.periodLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedMonth,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: List.generate(12, (i) {
                          return DropdownMenuItem(
                            value: i + 1,
                            child: Text(months[i]),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMonth = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedYear,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: [
                          DateTime.now().year - 1,
                          DateTime.now().year,
                          DateTime.now().year + 1,
                        ].map((y) {
                          return DropdownMenuItem(value: y, child: Text('$y'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedYear = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Payment Method
                Text(l10n.paymentMethodLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.paymentMethodCash),
                      selected: _paymentMethod == PaymentMethod.cash,
                      onSelected: (_) => setState(
                          () => _paymentMethod = PaymentMethod.cash),
                    ),
                    ChoiceChip(
                      label: Text(l10n.paymentMethodTelebirr),
                      selected: _paymentMethod == PaymentMethod.telebirr,
                      onSelected: (_) => setState(
                          () => _paymentMethod = PaymentMethod.telebirr),
                    ),
                    ChoiceChip(
                      label: Text(l10n.paymentMethodCbeBirr),
                      selected: _paymentMethod == PaymentMethod.cbeBirr,
                      onSelected: (_) => setState(
                          () => _paymentMethod = PaymentMethod.cbeBirr),
                    ),
                    ChoiceChip(
                      label: Text(l10n.paymentMethodBank),
                      selected: _paymentMethod == PaymentMethod.bankTransfer,
                      onSelected: (_) => setState(
                          () => _paymentMethod = PaymentMethod.bankTransfer),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Notes / Reference
                Text(l10n.notesLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Optional transaction or SMS reference',
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.save),
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
