import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/providers/sync_status_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../domain/models/contribution.dart';
import '../providers/contributions_provider.dart';
import 'contribution_detail_dialog.dart';
import 'record_contribution_dialog.dart';

class ContributionsScreen extends ConsumerWidget {
  const ContributionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final isTreasurer = user?.role == UserRole.treasurer;
    final isMember = user?.role == UserRole.member;

    final contributions = ref.watch(filteredContributionsProvider);
    final contributionsAsync = ref.watch(contributionsStreamProvider);
    final stats = ref.watch(contributionStatsProvider);
    final selectedMethod = ref.watch(contributionMethodFilterProvider);

    // If user is regular member, lookup their own member financial details
    final currentMember = isMember
        ? ref.watch(membersStreamProvider).valueOrNull?.where((m) => m.memberId == user?.memberId).firstOrNull
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMember ? l10n.myContributions : l10n.contributionsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              await ref.read(syncProvider.notifier).triggerSync();
            },
          ),
        ],
      ),
      floatingActionButton: isTreasurer
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const RecordContributionDialog(),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.recordPayment),
            )
          : null,
      body: Column(
        children: [
          // ── Top Summary Section ────────────────────────────────────────
          if (isMember && currentMember != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: AppColors.primary.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.balance,
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              '${currentMember.balance.toStringAsFixed(0)} ${l10n.currency}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: currentMember.balance >= 0
                                    ? AppColors.primary
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.arrears,
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                '${currentMember.arrears.toStringAsFixed(0)} ${l10n.currency}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: currentMember.arrears > 0
                                      ? AppColors.error
                                      : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (!isMember) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: l10n.thisMonth,
                      value:
                          '${stats.thisMonthTotal.toStringAsFixed(0)} ${l10n.currency}',
                      color: AppColors.success,
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: l10n.allTime,
                      value:
                          '${stats.allTimeTotal.toStringAsFixed(0)} ${l10n.currency}',
                      color: AppColors.primary,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Search Bar (only for admins/treasurers/auditors) ─────────────
          if (!isMember)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: TextField(
                onChanged: (val) {
                  ref.read(contributionSearchQueryProvider.notifier).state = val;
                },
                decoration: InputDecoration(
                  hintText: 'Search by receipt # or member name…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: ref
                          .watch(contributionSearchQueryProvider)
                          .isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            ref
                                .read(contributionSearchQueryProvider.notifier)
                                .state = '';
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

          // ── Payment Method Filter Chips ────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                FilterChip(
                  label: Text(l10n.filterAllMethods),
                  selected: selectedMethod == null,
                  onSelected: (_) {
                    ref.read(contributionMethodFilterProvider.notifier).state =
                        null;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.paymentMethodCash),
                  selected: selectedMethod == PaymentMethod.cash,
                  onSelected: (selected) {
                    ref.read(contributionMethodFilterProvider.notifier).state =
                        selected ? PaymentMethod.cash : null;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.paymentMethodTelebirr),
                  selected: selectedMethod == PaymentMethod.telebirr,
                  onSelected: (selected) {
                    ref.read(contributionMethodFilterProvider.notifier).state =
                        selected ? PaymentMethod.telebirr : null;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.paymentMethodCbeBirr),
                  selected: selectedMethod == PaymentMethod.cbeBirr,
                  onSelected: (selected) {
                    ref.read(contributionMethodFilterProvider.notifier).state =
                        selected ? PaymentMethod.cbeBirr : null;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.paymentMethodBank),
                  selected: selectedMethod == PaymentMethod.bankTransfer,
                  onSelected: (selected) {
                    ref.read(contributionMethodFilterProvider.notifier).state =
                        selected ? PaymentMethod.bankTransfer : null;
                  },
                ),
              ],
            ),
          ),

          // ── Contributions List ─────────────────────────────────────────
          Expanded(
            child: contributionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (_) {
                if (contributions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.emptyState,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(syncProvider.notifier).triggerSync();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: contributions.length,
                    itemBuilder: (context, index) {
                      final item = contributions[index];
                      return _ContributionCard(
                        contribution: item,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => ContributionDetailDialog(
                              contribution: item,
                            ),
                          );
                        },
                      );
                    },
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

class _StatCard extends StatelessWidget {
  const _StatCard({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributionCard extends StatelessWidget {
  const _ContributionCard({
    required this.contribution,
    required this.onTap,
  });

  final Contribution contribution;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = contribution;

    final methodTag = switch (c.paymentMethod) {
      PaymentMethod.cash => 'CASH',
      PaymentMethod.telebirr => 'TELEBIRR',
      PaymentMethod.cbeBirr => 'CBE BIRR',
      PaymentMethod.bankTransfer => 'BANK',
    };

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final monthStr =
        c.periodMonth >= 1 && c.periodMonth <= 12 ? months[c.periodMonth - 1] : '';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Receipt icon
              CircleAvatar(
                radius: 22,
                backgroundColor: c.isReversal
                    ? AppColors.error.withValues(alpha: 0.12)
                    : (c.isReversed
                        ? Colors.grey.withValues(alpha: 0.12)
                        : AppColors.success.withValues(alpha: 0.12)),
                child: Icon(
                  c.isReversal
                      ? Icons.undo
                      : (c.isReversed ? Icons.close : Icons.receipt),
                  color: c.isReversal
                      ? AppColors.error
                      : (c.isReversed ? Colors.grey : AppColors.success),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Member & Receipt Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.memberName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: c.isReversed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            methodTag,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${c.receiptNumber} • For $monthStr ${c.periodYear}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),

              // Amount & Date
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${c.isReversal ? "-" : "+"}${c.amount.toStringAsFixed(0)} ETB',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: c.isReversal
                          ? AppColors.error
                          : (c.isReversed ? Colors.grey : AppColors.success),
                      decoration:
                          c.isReversed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${c.date.month}/${c.date.day}/${c.date.year}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
