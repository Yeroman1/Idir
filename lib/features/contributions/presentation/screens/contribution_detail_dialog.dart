import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/contribution.dart';
import '../providers/contributions_provider.dart';

class ContributionDetailDialog extends ConsumerStatefulWidget {
  const ContributionDetailDialog({
    super.key,
    required this.contribution,
  });

  final Contribution contribution;

  @override
  ConsumerState<ContributionDetailDialog> createState() =>
      _ContributionDetailDialogState();
}

class _ContributionDetailDialogState
    extends ConsumerState<ContributionDetailDialog> {
  bool _isReversing = false;

  Future<void> _showReversalConfirmation() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.reverseTransaction),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.reversalConfirm,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.reversalReasonLabel,
                  hintText: 'e.g. Mistake in member selection or duplicate entry',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Reversal reason is mandatory for audit log'
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

    if (confirmed == true && mounted) {
      setState(() => _isReversing = true);
      final currentUser = ref.read(currentUserProvider);
      final success = await ref
          .read(contributionActionNotifierProvider.notifier)
          .reversePayment(
            originalId: widget.contribution.id,
            reason: reasonCtrl.text.trim(),
            recordedByUid: currentUser?.uid ?? 'treasurer',
            recordedByName: currentUser?.name ?? 'Treasurer',
          );

      if (mounted) {
        setState(() => _isReversing = false);
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.reversalRecordedSuccess),
              backgroundColor: AppColors.success,
            ),
          );
          navigator.pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final canReverse = user?.role == UserRole.treasurer;
    final c = widget.contribution;

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final periodStr =
        c.periodMonth >= 1 && c.periodMonth <= 12
            ? '${months[c.periodMonth - 1]} ${c.periodYear}'
            : '${c.periodYear}';

    final methodStr = switch (c.paymentMethod) {
      PaymentMethod.cash => l10n.paymentMethodCash,
      PaymentMethod.telebirr => l10n.paymentMethodTelebirr,
      PaymentMethod.cbeBirr => l10n.paymentMethodCbeBirr,
      PaymentMethod.bankTransfer => l10n.paymentMethodBank,
    };

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      c.receiptNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Reversal Status Warning Banner
              if (c.isReversed) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l10n.isReversed} — This payment has been reversed and voided.',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (c.isReversal) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.undo,
                          color: AppColors.warning, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l10n.reversalRecord} for receipt #${c.reversalOfId ?? "original"}',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Prominent Amount
              Center(
                child: Column(
                  children: [
                    Text(
                      '${c.isReversal ? "-" : "+"}${c.amount.toStringAsFixed(0)} ${l10n.currency}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: c.isReversal
                            ? AppColors.error
                            : (c.isReversed
                                ? Colors.grey
                                : AppColors.success),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      periodStr,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Details List
              _ReceiptRow(
                icon: Icons.person_outline,
                label: l10n.membersTitle,
                value: '${c.memberName} (${c.memberId})',
              ),
              const SizedBox(height: 12),
              _ReceiptRow(
                icon: Icons.payments_outlined,
                label: l10n.paymentMethodLabel,
                value: methodStr,
              ),
              const SizedBox(height: 12),
              _ReceiptRow(
                icon: Icons.calendar_today_outlined,
                label: l10n.paymentDateLabel,
                value:
                    '${c.date.year}-${c.date.month.toString().padLeft(2, '0')}-${c.date.day.toString().padLeft(2, '0')} at ${c.date.hour.toString().padLeft(2, '0')}:${c.date.minute.toString().padLeft(2, '0')}',
              ),
              const SizedBox(height: 12),
              _ReceiptRow(
                icon: Icons.badge_outlined,
                label: l10n.recordedByLabel,
                value: c.recordedByName,
              ),

              if (c.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ReceiptRow(
                  icon: Icons.notes_outlined,
                  label: l10n.notesLabel,
                  value: c.notes,
                ),
              ],

              if (c.reversalReason != null &&
                  c.reversalReason!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ReceiptRow(
                  icon: Icons.info_outline,
                  label: l10n.reversalReasonLabel,
                  value: c.reversalReason!,
                ),
              ],

              const SizedBox(height: 24),

              // Reversal Action Button (Treasurer only)
              if (canReverse && !c.isReversed && !c.isReversal)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  icon: _isReversing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.error,
                          ),
                        )
                      : const Icon(Icons.undo),
                  label: Text(l10n.reverseTransaction),
                  onPressed: _isReversing
                      ? null
                      : _showReversalConfirmation,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
