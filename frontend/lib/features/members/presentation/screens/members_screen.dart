import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../../../../core/providers/sync_status_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../invitations/presentation/widgets/invite_members_dialog.dart';
import '../../domain/models/member.dart';
import '../providers/members_provider.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final canManage = user?.role.canManageMembers ?? false;

    final members = ref.watch(filteredMembersProvider);
    final selectedFilter = ref.watch(memberStatusFilterProvider);
    final membersAsync = ref.watch(membersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.membersTitle),
            if (MediaQuery.sizeOf(context).width < 420)
              Text(
                '${members.length} ${l10n.memberCount}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.email_outlined),
              tooltip: 'Invite Member by Email / Phone',
              onPressed: () {
                final activeIdir = ref.read(activeIdirProvider).activeIdir;
                if (activeIdir != null) {
                  showDialog(
                    context: context,
                    builder: (_) => InviteMembersDialog(
                      idirId: activeIdir.idirId,
                      idirName: activeIdir.idirName,
                    ),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              await ref.read(syncProvider.notifier).triggerSync();
            },
          ),
          if (MediaQuery.sizeOf(context).width >= 420)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${members.length} ${l10n.memberCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'invite_member_fab',
              onPressed: () {
                final activeIdir = ref.read(activeIdirProvider).activeIdir;
                if (activeIdir != null) {
                  showDialog(
                    context: context,
                    builder: (_) => InviteMembersDialog(
                      idirId: activeIdir.idirId,
                      idirName: activeIdir.idirName,
                    ),
                  );
                }
              },
              backgroundColor: AppColors.secondary,
              icon: const Icon(Icons.email_outlined),
              label: const Text('Invite Member'),
            )
          : null,
      body: Column(
        children: [
          // ── Search Bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (val) {
                ref.read(memberSearchQueryProvider.notifier).state = val;
              },
              decoration: InputDecoration(
                hintText: l10n.searchMembers,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ref.watch(memberSearchQueryProvider).isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          ref.read(memberSearchQueryProvider.notifier).state =
                              '';
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // ── Status Filter Chips ────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                FilterChip(
                  label: Text(l10n.filterAll),
                  selected: selectedFilter == null,
                  onSelected: (_) {
                    ref.read(memberStatusFilterProvider.notifier).state = null;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.statusActive),
                  selected: selectedFilter == MemberStatus.active,
                  onSelected: (selected) {
                    ref.read(memberStatusFilterProvider.notifier).state =
                        selected ? MemberStatus.active : null;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.statusSuspended),
                  selected: selectedFilter == MemberStatus.suspended,
                  onSelected: (selected) {
                    ref.read(memberStatusFilterProvider.notifier).state =
                        selected ? MemberStatus.suspended : null;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.statusDeceased),
                  selected: selectedFilter == MemberStatus.deceased,
                  onSelected: (selected) {
                    ref.read(memberStatusFilterProvider.notifier).state =
                        selected ? MemberStatus.deceased : null;
                  },
                ),
              ],
            ),
          ),

          // ── Members List ───────────────────────────────────────────────
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error: $err',
                    style: const TextStyle(color: AppColors.error)),
              ),
              data: (_) {
                if (members.isEmpty) {
                  final activeIdirId = ref.watch(activeIdirIdProvider);
                  final isNoIdir = activeIdirId == null;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isNoIdir ? Icons.lock_outline : Icons.people_outline,
                            size: 64,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isNoIdir
                                ? 'Membership is private'
                                : (ref.watch(memberSearchQueryProvider).isNotEmpty
                                    ? l10n.searchNoResults
                                    : l10n.emptyState),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (isNoIdir) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Idir membership lists are restricted to registered members. You do not currently belong to an active Idir.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () => context.go(AppRoutes.home),
                              icon: const Icon(Icons.home_outlined),
                              label: const Text('Go to Home Dashboard'),
                            ),
                          ],
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final m = members[index];
                      return _MemberCard(
                        member: m,
                        onTap: () {
                          context.push('${AppRoutes.members}/detail/${m.id}');
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

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.onTap,
  });

  final Member member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final statusColor = switch (member.status) {
      MemberStatus.active => AppColors.success,
      MemberStatus.suspended => AppColors.warning,
      MemberStatus.deceased => Colors.grey.shade700,
    };

    final statusText = switch (member.status) {
      MemberStatus.active => 'ACTIVE',
      MemberStatus.suspended => 'SUSPENDED',
      MemberStatus.deceased => 'DECEASED',
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  member.fullName.isNotEmpty
                      ? member.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name, Member ID, Phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.fullName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor, width: 0.8),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${member.memberId} • ${member.phone}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.65),
                      ),
                    ),

                    // Arrears alert if any
                    if (member.arrears > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Arrears: ${member.arrears.toStringAsFixed(0)} ETB',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
