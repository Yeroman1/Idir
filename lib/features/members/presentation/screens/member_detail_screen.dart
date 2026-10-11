import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reports/domain/models/report_models.dart';
import '../../../reports/presentation/providers/reports_provider.dart';
import '../../domain/models/member.dart';
import '../providers/members_provider.dart';

class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({
    super.key,
    required this.memberId,
  });

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final canManage = user?.role.canManageMembers ?? false;

    final membersAsync = ref.watch(membersStreamProvider);
    final memberList = membersAsync.valueOrNull ?? [];
    final member = memberList
        .where((m) => m.id == memberId || m.memberId == memberId)
        .firstOrNull;

    if (member == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.memberDetail)),
        body: membersAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(child: Text(l10n.emptyState)),
      );
    }

    final statusColor = switch (member.status) {
      MemberStatus.active => AppColors.success,
      MemberStatus.suspended => AppColors.warning,
      MemberStatus.deceased => Colors.grey.shade700,
    };

    final statusText = switch (member.status) {
      MemberStatus.active => l10n.statusActive,
      MemberStatus.suspended => l10n.statusSuspended,
      MemberStatus.deceased => l10n.statusDeceased,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(member.fullName),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export Statement PDF',
            onPressed: () {
              ref.read(selectedReportTypeProvider.notifier).state =
                  ReportType.memberStatement;
              ref.read(selectedReportMemberIdProvider.notifier).state =
                  member.id;
              context.push(AppRoutes.reports);
            },
          ),
          if (canManage) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editMember,
              onPressed: () {
                context.push('${AppRoutes.members}/edit/${member.id}');
              },
            ),
            PopupMenuButton<String>(
              onSelected: (val) async {
                if (val == 'toggle_status') {
                  final actionNotifier =
                      ref.read(memberActionNotifierProvider.notifier);
                  final success =
                      await actionNotifier.toggleMemberStatus(member);
                  if (context.mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.memberUpdatedSuccess),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } else if (val == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.deleteMember),
                      content: Text(l10n.memberDeleteConfirm),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l10n.cancel),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    await ref
                        .read(memberActionNotifierProvider.notifier)
                        .deleteMember(member.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.memberDeletedSuccess),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      context.pop();
                    }
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle_status',
                  child: Row(
                    children: [
                      Icon(
                        member.isActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        color: member.isActive
                            ? AppColors.warning
                            : AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(member.isActive
                          ? l10n.suspendMember
                          : l10n.activateMember),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.deleteMember,
                          style: const TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile Banner Card ────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      member.fullName.isNotEmpty
                          ? member.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    member.fullName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.memberId,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1.2),
                    ),
                    child: Text(
                      statusText.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Financial Overview Cards Row ───────────────────────────────
          Row(
            children: [
              Expanded(
                child: _FinanceCard(
                  label: l10n.balance,
                  value: '${member.balance.toStringAsFixed(0)} ${l10n.currency}',
                  color: member.balance >= 0
                      ? AppColors.primary
                      : AppColors.error,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FinanceCard(
                  label: l10n.arrears,
                  value: '${member.arrears.toStringAsFixed(0)} ${l10n.currency}',
                  color: member.arrears > 0
                      ? AppColors.error
                      : AppColors.success,
                  icon: Icons.warning_amber_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── General Information Card ───────────────────────────────────
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(l10n.phoneLabel),
                  subtitle: Text(member.phone),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(l10n.monthlyDuesLabel),
                  subtitle: Text(
                      '${member.monthlyDues.toStringAsFixed(0)} ${l10n.currency} / month'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(l10n.registeredDateLabel),
                  subtitle: Text(
                    '${member.registeredAt.year}-${member.registeredAt.month.toString().padLeft(2, '0')}-${member.registeredAt.day.toString().padLeft(2, '0')}',
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: Text(l10n.totalPaidLabel),
                  subtitle: Text(
                      '${member.totalPaid.toStringAsFixed(0)} ${l10n.currency}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Emergency Contact Card ─────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.contact_phone_outlined,
                          color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.emergencyContactTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (member.emergencyContact != null &&
                      member.emergencyContact!.name.isNotEmpty) ...[
                    Text(
                      member.emergencyContact!.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${member.emergencyContact!.relationship} • ${member.emergencyContact!.phone}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'None recorded',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Dependents / Covered Family Card ───────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.family_restroom_outlined,
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${l10n.dependentsTitle} (${member.dependents.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (member.dependents.isNotEmpty)
                    ...member.dependents.map(
                      (d) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              d.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${d.relationship})',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Text(
                      l10n.noDependents,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Notes / Remarks ────────────────────────────────────────────
          if (member.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.notesLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      member.notes,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
