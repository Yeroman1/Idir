import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/claims_repository.dart';
import '../../domain/models/claim.dart';
import '../providers/claims_provider.dart';
import 'claim_detail_dialog.dart';
import 'submit_claim_dialog.dart';

class ClaimsScreen extends ConsumerWidget {
  const ClaimsScreen({super.key});

  Color _statusColor(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.submitted:
        return AppColors.warning;
      case ClaimStatus.approved:
        return const Color(0xFF1565C0);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final claims = ref.watch(filteredClaimsProvider);
    final currentFilter = ref.watch(claimsFilterProvider);

    final canSubmit = user?.role == UserRole.chairperson ||
        user?.role == UserRole.treasurer ||
        user?.role == UserRole.member;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.claimsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              await ref.read(claimsRepositoryProvider).getClaims();
            },
          ),
        ],
      ),
      floatingActionButton: canSubmit
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const SubmitClaimDialog(),
                );
              },
              icon: const Icon(Icons.post_add),
              label: Text(l10n.submitClaim),
            )
          : null,
      body: Column(
        children: [
          // ── Search & Filter Bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              hintText: 'Search claims by member or number…',
              leading: const Icon(Icons.search),
              trailing: [
                if (ref.watch(claimsSearchQueryProvider).isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      ref.read(claimsSearchQueryProvider.notifier).state = '';
                    },
                  ),
              ],
              onChanged: (q) {
                ref.read(claimsSearchQueryProvider.notifier).state = q;
              },
            ),
          ),

          // ── Status Filter Chips ──────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: Text(l10n.filterAll),
                  selected: currentFilter == null,
                  onSelected: (_) {
                    ref.read(claimsFilterProvider.notifier).state = null;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.claimStatus_submitted),
                  selected: currentFilter == ClaimStatus.submitted,
                  onSelected: (_) {
                    ref.read(claimsFilterProvider.notifier).state =
                        ClaimStatus.submitted;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.claimStatus_approved),
                  selected: currentFilter == ClaimStatus.approved,
                  onSelected: (_) {
                    ref.read(claimsFilterProvider.notifier).state =
                        ClaimStatus.approved;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.claimStatus_paid),
                  selected: currentFilter == ClaimStatus.paid,
                  onSelected: (_) {
                    ref.read(claimsFilterProvider.notifier).state =
                        ClaimStatus.paid;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.claimStatus_rejected),
                  selected: currentFilter == ClaimStatus.rejected,
                  onSelected: (_) {
                    ref.read(claimsFilterProvider.notifier).state =
                        ClaimStatus.rejected;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // ── Claims List ──────────────────────────────────────────────────
          Expanded(
            child: claims.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 56,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.emptyState,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                    itemCount: claims.length,
                    itemBuilder: (context, index) {
                      final c = claims[index];
                      final statusColor = _statusColor(c.status);
                      final dateStr =
                          DateFormat('dd MMM yyyy').format(c.createdAt);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => ClaimDetailDialog(claim: c),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: Number & Status Badge
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
                                            color: AppColors.primary
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            c.claimNumber,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          c.type.name.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                          color: statusColor
                                              .withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: Text(
                                        _statusLabel(c.status, l10n),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Beneficiary Name & ID
                                Text(
                                  c.memberName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${c.memberId} • $dateStr',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Narrative excerpt
                                Text(
                                  c.description,
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 10),

                                // Bottom row: Requested amount & Approvals progress
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Requested',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          'ETB ${c.requestedAmount.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (c.status == ClaimStatus.paid &&
                                        c.payoutAmount != null)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Paid Payout',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          Text(
                                            'ETB ${c.payoutAmount!.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.how_to_vote_outlined,
                                              size: 14,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${c.approvedCount}/2 approvals',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: c.approvedCount >= 2
                                                    ? AppColors.success
                                                    : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
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
