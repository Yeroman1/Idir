import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/claim.dart';
import '../providers/claims_provider.dart';

class ClaimDetailDialog extends ConsumerStatefulWidget {
  const ClaimDetailDialog({super.key, required this.claim});

  final Claim claim;

  @override
  ConsumerState<ClaimDetailDialog> createState() => _ClaimDetailDialogState();
}

class _ClaimDetailDialogState extends ConsumerState<ClaimDetailDialog> {
  bool _isActionLoading = false;

  Color _statusColor(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.submitted:
        return AppColors.warning;
      case ClaimStatus.approved:
        return const Color(0xFF1565C0); // Blue
      case ClaimStatus.paid:
        return AppColors.success;
      case ClaimStatus.rejected:
        return AppColors.error;
    }
  }

  String _statusLabel(ClaimStatus status, AppLocalizations l10n) {
    switch (status) {
      case ClaimStatus.submitted:
        return l10n.claimStatus_submitted;
      case ClaimStatus.approved:
        return l10n.claimStatus_approved;
      case ClaimStatus.paid:
        return l10n.claimStatus_paid;
      case ClaimStatus.rejected:
        return l10n.claimStatus_rejected;
    }
  }

  Future<void> _handleVote({required String decision}) async {
    final commentCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final l10n = AppLocalizations.of(context);
    final isApprove = decision == 'approved';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? l10n.approveClaim : l10n.rejectClaim),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isApprove
                    ? 'Confirm approval of this mutual-aid claim for committee record.'
                    : 'State reason for rejecting this claim (mandatory for audit trail).',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: commentCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Audit Comment / Notes *',
                  hintText: 'e.g. Verified hospital records / eligibility criteria',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Audit explanation is required'
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
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? AppColors.success : AppColors.error,
            ),
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
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final currentUser = ref.read(currentUserProvider);

      setState(() => _isActionLoading = true);

      final success = await ref
          .read(claimActionNotifierProvider.notifier)
          .voteOnClaim(
            claimId: widget.claim.id,
            uid: currentUser?.uid ?? 'unknown',
            name: currentUser?.name ?? 'Officer',
            role: currentUser?.role.name ?? 'chairperson',
            decision: decision,
            comment: commentCtrl.text.trim(),
          );

      if (mounted) {
        setState(() => _isActionLoading = false);
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(isApprove
                  ? 'Vote recorded: Approved'
                  : 'Vote recorded: Rejected'),
              backgroundColor: isApprove ? AppColors.success : AppColors.error,
            ),
          );
          navigator.pop();
        }
      }
    }
  }

  Future<void> _handlePayout() async {
    final amountCtrl = TextEditingController(
      text: widget.claim.requestedAmount.toStringAsFixed(0),
    );
    final formKey = GlobalKey<FormState>();
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.recordPayout),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Disburse mutual-aid payout. This will generate an append-only expense voucher in the association ledger.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: amountCtrl,
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
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
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final currentUser = ref.read(currentUserProvider);
      final payout = double.tryParse(amountCtrl.text.trim()) ?? widget.claim.requestedAmount;

      setState(() => _isActionLoading = true);

      final success = await ref
          .read(claimActionNotifierProvider.notifier)
          .recordPayout(
            claimId: widget.claim.id,
            payoutAmount: payout,
            recordedByUid: currentUser?.uid ?? 'treasurer',
            recordedByName: currentUser?.name ?? 'Treasurer',
          );

      if (mounted) {
        setState(() => _isActionLoading = false);
        if (success) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Payout disbursed and recorded in expenses ledger'),
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
    final currentUser = ref.watch(currentUserProvider);
    final c = widget.claim;
    final statusColor = _statusColor(c.status);

    final isSelfSubmitted = currentUser?.uid == c.submittedBy;
    final hasAlreadyVoted = currentUser != null && c.hasVoted(currentUser.uid);
    final canVote = currentUser != null && c.canVote(currentUser.uid, currentUser.role);
    final canPayout = currentUser != null && c.canRecordPayout(currentUser.role);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header Row ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.claimNumber,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(c.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _statusLabel(c.status, l10n),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // ── Beneficiary Details ──────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: const Icon(Icons.person, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.memberName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'ID: ${c.memberId} • Type: ${c.type.name.toUpperCase()}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Financial Box ────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Requested Assistance',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ETB ${c.requestedAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (c.payoutAmount != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Disbursed Payout',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ETB ${c.payoutAmount!.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Circumstances Description ────────────────────────────────
              Text(
                'Circumstances & Reason',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
                ),
                child: Text(
                  c.description,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 18),

              // ── Approvals Timeline ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Committee Approvals Timeline',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${c.approvedCount} of ${AppConstants.defaultClaimApprovalsRequired} required',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.approvedCount >= AppConstants.defaultClaimApprovalsRequired
                          ? AppColors.success
                          : AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (c.approvals.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'No officer votes recorded yet. Pending committee review.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                )
              else
                ...c.approvals.map((appr) {
                  final isApp = appr.decision == 'approved';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isApp
                          ? AppColors.success.withValues(alpha: 0.08)
                          : AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isApp
                            ? AppColors.success.withValues(alpha: 0.25)
                            : AppColors.error.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isApp ? Icons.check_circle : Icons.cancel,
                          size: 18,
                          color: isApp ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    appr.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd MMM, HH:mm').format(appr.at),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '"${appr.comment}"',
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 16),

              // ── Security Constraints Notice (Self-approval / Already voted)
              if (isSelfSubmitted && c.status == ClaimStatus.submitted)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppColors.secondary, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Self-Approval Prevention Rule: You cannot vote on a claim you submitted.',
                          style: TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else if (hasAlreadyVoted && c.status == ClaimStatus.submitted)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have already recorded your vote on this claim.',
                          style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Action Buttons ───────────────────────────────────────────
              if (_isActionLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (canVote)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          icon: const Icon(Icons.close, size: 18),
                          label: Text(l10n.rejectClaim),
                          onPressed: () => _handleVote(decision: 'rejected'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(l10n.approveClaim),
                          onPressed: () => _handleVote(decision: 'approved'),
                        ),
                      ),
                    ],
                  ),
                if (canPayout) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 46),
                    ),
                    icon: const Icon(Icons.payments_outlined, size: 20),
                    label: Text(l10n.recordPayout),
                    onPressed: _handlePayout,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
