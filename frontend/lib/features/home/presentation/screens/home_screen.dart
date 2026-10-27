import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/pin_provider.dart';
import '../../../../core/providers/sync_status_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/offline_indicator_bar.dart';
import '../../../../core/widgets/theme_mode_toggle.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../contributions/domain/models/contribution.dart';
import '../../../contributions/presentation/screens/record_contribution_dialog.dart';
import '../../domain/models/dashboard_stats.dart';
import '../providers/dashboard_provider.dart';
import '../../../idirs/domain/models/idir_model.dart';
import '../../../idirs/presentation/providers/idir_creation_provider.dart';
import '../../../invitations/presentation/providers/invitations_provider.dart';
import '../../../invitations/presentation/widgets/invite_members_dialog.dart';
import '../../../invitations/presentation/widgets/received_invitations_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final pinState = ref.watch(pinNotifierProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    final activeIdirState = ref.watch(activeIdirProvider);
    final activeIdir = activeIdirState.activeIdir;

    final effectiveRole = activeIdir?.role ?? user?.role ?? UserRole.member;
    final isRegularMember = effectiveRole == UserRole.member;
    final officerStats = ref.watch(dashboardStatsProvider);
    final memberStats = ref.watch(memberPersonalDashboardProvider);
    final pinned = isRegularMember
        ? memberStats.pinnedAnnouncement
        : officerStats.pinnedAnnouncement;

    final draftIdirAsync = ref.watch(userDraftIdirProvider);
    final draftIdir = draftIdirAsync.value;
    final hasActiveIdir =
        activeIdir != null || (user?.hasIdir == true) || draftIdir != null;
    final currentIdirName = activeIdir?.idirName ??
        draftIdir?.name ??
        user?.idirName ??
        l10n.associationName;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.dashboardTitle),
            Text(
              hasActiveIdir ? currentIdirName : 'Idir Community Network',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          // ── Sync Status Chip ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: _SyncStatusChip(syncStatus: syncStatus, l10n: l10n),
          ),

          // ── Group Chat Action Button ─────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: l10n.groupChatTitle,
            onPressed: () => context.push(AppRoutes.chat),
          ),

          // ── Refresh Action Button ────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing live data from Supabase...'),
                  duration: Duration(milliseconds: 900),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              await ref.read(syncProvider.notifier).triggerSync();
              await ref.read(authNotifierProvider.notifier).refreshCurrentUser();
              ref.read(userDraftIdirProvider.notifier).loadDraft();
              ref.invalidate(dashboardStatsProvider);
              ref.invalidate(memberPersonalDashboardProvider);
            },
          ),

          // ── Language Selector ────────────────────────────────────────────
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            tooltip: 'Language',
            onSelected: (loc) {
              ref.read(localeProvider.notifier).setLocale(loc);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: Locale('en'), child: Text('English')),
              PopupMenuItem(value: Locale('am'), child: Text('አማርኛ (Amharic)')),
              PopupMenuItem(value: Locale('om'), child: Text('Afaan Oromoo')),
            ],
          ),

          // ── Theme Mode Toggle ───────────────────────────────────────────
          const ThemeModeToggle(),

          // ── Security Quick Lock Button ────────────────────────────────────
          if (pinState.isSet)
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Lock app',
              onPressed: () {
                ref.read(pinNotifierProvider.notifier).lock();
                context.go(AppRoutes.pin);
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(syncProvider.notifier).triggerSync();
          await ref.read(authNotifierProvider.notifier).refreshCurrentUser();
          ref.read(userDraftIdirProvider.notifier).loadDraft();
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(memberPersonalDashboardProvider);
          ref.invalidate(receivedInvitationsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── 1. User Profile & Role Card ───────────────────────────────
            if (user != null)
              _UserProfileHeader(
                user: user,
                l10n: l10n,
                hasActiveIdir: hasActiveIdir,
                activeIdir: activeIdir,
              ),
            const SizedBox(height: 14),

            // ── 1.0 Incoming Idir Invitations ─────────────────────────────
            const ReceivedInvitationsBanner(),

            if (!hasActiveIdir) ...[
              _NoIdirOnboardingView(user: user),
              const SizedBox(height: 24),
            ] else ...[
              // ── 1.1 Idir Status Card (with DRAFT badge) ───────────────────
              if (draftIdir != null) ...[
                _DraftIdirDashboardCard(idir: draftIdir),
                const SizedBox(height: 14),
              ],

            // ── 2. Pinned Announcement Banner ──────────────────────────────
            if (pinned != null) ...[
              _PinnedAnnouncementBanner(announcement: pinned, l10n: l10n),
              const SizedBox(height: 16),
            ],

            // ── 3. Role-Based Financial Overview ───────────────────────────
            if (isRegularMember) ...[
              _MemberPersonalStandingCard(
                stats: memberStats,
                l10n: l10n,
                onViewReceipts: () => context.go(AppRoutes.contributions),
              ),
            ] else ...[
              _OfficerFinancialOverview(
                stats: officerStats,
                l10n: l10n,
                onViewContributions: () => context.go(AppRoutes.contributions),
                onViewMembers: () => context.go(AppRoutes.members),
                onViewClaims: () => context.go(AppRoutes.claims),
              ),
            ],
            const SizedBox(height: 20),

            // ── 4. Quick Actions ───────────────────────────────────────────
            Text(
              l10n.quickActions,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            _QuickActionsGrid(
              userRole: effectiveRole,
              l10n: l10n,
              isDraft: draftIdir != null && draftIdir.isDraft,
              onRecordPayment: () {
                showDialog(
                  context: context,
                  builder: (_) => const RecordContributionDialog(),
                );
              },
              onInviteMember: () {
                final targetId = activeIdir?.idirId ?? draftIdir?.id;
                final targetName = activeIdir?.idirName ?? draftIdir?.name ?? 'Idir';
                if (targetId != null) {
                  showDialog(
                    context: context,
                    builder: (_) => InviteMembersDialog(
                      idirId: targetId,
                      idirName: targetName,
                    ),
                  );
                } else {
                  context.push(AppRoutes.membersAdd);
                }
              },
            ),
            const SizedBox(height: 24),

            // ── 5. Recent Activity Feed ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.recentActivity,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (isRegularMember) {
                      context.go(AppRoutes.contributions);
                    } else {
                      context.push(AppRoutes.auditLog);
                    }
                  },
                  child: Text(l10n.viewAll),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (isRegularMember)
              _MemberRecentReceiptsList(
                receipts: memberStats.recentContributions,
                l10n: l10n,
              )
            else
              _OfficerActivityFeed(
                activities: officerStats.recentActivities,
                l10n: l10n,
              ),
            const SizedBox(height: 32),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createIdir),
        icon: const Icon(Icons.add),
        label: const Text('Create Idir'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync Status Indicator Chip
// ─────────────────────────────────────────────────────────────────────────────

class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({required this.syncStatus, required this.l10n});

  final SyncStatus syncStatus;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    String label;

    switch (syncStatus) {
      case SyncStatus.synced:
        dotColor = AppColors.success;
        label = l10n.syncedLabel;
      case SyncStatus.syncing:
        dotColor = AppColors.secondary;
        label = l10n.syncingLabel;
      case SyncStatus.offline:
        dotColor = AppColors.warning;
        label = l10n.offlineLabel;
      case SyncStatus.error:
        dotColor = AppColors.error;
        label = 'Sync Error';
    }

    return InkWell(
      onTap: () => showOfflineSyncModal(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: dotColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dotColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: dotColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User Profile Header
// ─────────────────────────────────────────────────────────────────────────────

class _UserProfileHeader extends StatelessWidget {
  const _UserProfileHeader({
    required this.user,
    required this.l10n,
    this.hasActiveIdir = true,
    this.activeIdir,
  });

  final AppUser user;
  final AppLocalizations l10n;
  final bool hasActiveIdir;
  final UserMembership? activeIdir;

  String _roleLabel(UserRole role) {
    if (!hasActiveIdir) {
      return 'Pending Idir';
    }
    switch (role) {
      case UserRole.chairperson:
        return l10n.roleChairperson;
      case UserRole.treasurer:
        return l10n.roleTreasurer;
      case UserRole.auditor:
        return l10n.roleAuditor;
      case UserRole.member:
        return l10n.roleMember;
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.chairperson:
        return AppColors.primary;
      case UserRole.treasurer:
        return AppColors.secondary;
      case UserRole.auditor:
        return const Color(0xFF1565C0);
      case UserRole.member:
        return const Color(0xFF4E7D6B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveRole = activeIdir?.role ?? user.role;
    final roleColor = _roleColor(effectiveRole);
    final effectiveMemberId = (activeIdir?.memberNumber.isNotEmpty == true)
        ? activeIdir!.memberNumber
        : user.memberId;
    final currentIdirTitle = activeIdir?.idirName ?? user.idirName;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: roleColor.withValues(alpha: 0.15),
            child: Text(
              user.name.isNotEmpty ? user.name[0] : 'U',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: roleColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (currentIdirTitle != null && currentIdirTitle.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.groups_outlined,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 140),
                              child: Text(
                                currentIdirTitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _roleLabel(effectiveRole),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasActiveIdir
                          ? (effectiveMemberId.isNotEmpty
                              ? effectiveMemberId
                              : 'IDIR Member')
                          : 'No Active Community',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Draft Idir Dashboard Card
// ─────────────────────────────────────────────────────────────────────────────

class _DraftIdirDashboardCard extends StatelessWidget {
  const _DraftIdirDashboardCard({required this.idir});

  final IdirModel idir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      idir.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${idir.community} • ${idir.location}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Prominent DRAFT Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'DRAFT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (idir.purpose.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              idir.purpose,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Contribution Regular Dues:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                'ETB ${idir.contributionAmount.toStringAsFixed(0)} / ${idir.contributionFrequency.toLowerCase()}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Financial & claim actions are locked. Available once this Idir is active.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => InviteMembersDialog(
                    idirId: idir.id,
                    idirName: idir.name,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Invite Members (Email / Phone)'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// No Active Idir Onboarding View
// ─────────────────────────────────────────────────────────────────────────────

class _NoIdirOnboardingView extends StatefulWidget {
  const _NoIdirOnboardingView({this.user});

  final AppUser? user;

  @override
  State<_NoIdirOnboardingView> createState() => _NoIdirOnboardingViewState();
}

class _NoIdirOnboardingViewState extends State<_NoIdirOnboardingView> {
  final _inviteTokenController = TextEditingController();

  @override
  void dispose() {
    _inviteTokenController.dispose();
    super.dispose();
  }

  void _submitInviteCode() {
    final token = _inviteTokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an invitation token or code'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    context.push('${AppRoutes.invitation}?token=$token');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Member Account Welcome Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.12),
                AppColors.secondary.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verified Member Account',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        if (widget.user?.phone != null && widget.user!.phone.isNotEmpty)
                          Text(
                            widget.user!.phone,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'You have not joined or established an Idir yet. To get started, you can establish your community Idir as its Leader or join an existing Idir using an invite code.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Option A: Establish New Idir (Leader)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Establish a New Idir',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'You will be the Leader (Chairperson)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Found a community association for your kebele, neighborhood, or organization. As the creator, your role will automatically be Chairperson, allowing you to configure dues, invite members, and manage claims.',
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.createIdir),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Create Idir as Leader',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Option B: Join Existing Idir via Invitation
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.group_add_outlined,
                      color: AppColors.secondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Join via Invitation',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Default Role: Community Member',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'If an Idir officer invited you via SMS or shared an invite code, enter your invitation token below to join their community.',
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inviteTokenController,
                      decoration: InputDecoration(
                        hintText: 'Enter invite code or token',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onSubmitted: (_) => _submitInviteCode(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _submitInviteCode,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Join'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinned Announcement Banner
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedAnnouncementBanner extends StatelessWidget {
  const _PinnedAnnouncementBanner({
    required this.announcement,
    required this.l10n,
  });

  final PinnedAnnouncement announcement;
  final AppLocalizations l10n;

  void _showFullAnnouncement(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.push_pin, color: AppColors.secondary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                announcement.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    announcement.category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM yyyy').format(announcement.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              announcement.body,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Posted by: ${announcement.postedByName}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.announcements);
            },
            child: const Text('View All'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _showFullAnnouncement(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.push_pin,
                color: AppColors.secondary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.pinnedNotice,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• ${DateFormat('dd MMM').format(announcement.createdAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    announcement.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    announcement.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Officer Institutional Overview
// ─────────────────────────────────────────────────────────────────────────────

class _OfficerFinancialOverview extends StatelessWidget {
  const _OfficerFinancialOverview({
    required this.stats,
    required this.l10n,
    required this.onViewContributions,
    required this.onViewMembers,
    required this.onViewClaims,
  });

  final DashboardStats stats;
  final AppLocalizations l10n;
  final VoidCallback onViewContributions;
  final VoidCallback onViewMembers;
  final VoidCallback onViewClaims;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat('#,##0.00');

    return Column(
      children: [
        // ── Main Hero Card: Total Fund ────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF0F473B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.totalFund,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${stats.activeMembersCount} ${l10n.activeMembers}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ETB ${currencyFormat.format(stats.totalFund)}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _HeroStat(
                    label: l10n.thisMonth,
                    value: 'ETB ${stats.collectedThisMonth.toStringAsFixed(0)}',
                  ),
                  _HeroStat(
                    label: l10n.target,
                    value: 'ETB ${stats.expectedThisMonth.toStringAsFixed(0)}',
                  ),
                  _HeroStat(
                    label: l10n.collectionProgress,
                    value:
                        '${(stats.collectionProgress * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Monthly Collection Progress Bar Card ──────────────────────────
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
          ),
          child: InkWell(
            onTap: onViewContributions,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.trending_up,
                              size: 18, color: AppColors.success),
                          const SizedBox(width: 8),
                          Text(
                            l10n.thisMonthCollected,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${(stats.collectionProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: stats.collectionProgress,
                      minHeight: 8,
                      backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation(AppColors.success),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${l10n.collected}: ETB ${stats.collectedThisMonth.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        '${l10n.target}: ETB ${stats.expectedThisMonth.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Secondary Metric Cards Row (Members, Arrears & Claims) ────────
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.people_outline,
                title: l10n.memberCount,
                value: '${stats.totalMembersCount}',
                subtitle: '${stats.activeMembersCount} ${l10n.activeMembers}',
                accentColor: AppColors.primary,
                onTap: onViewMembers,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: Icons.warning_amber_rounded,
                title: l10n.membersInArrears,
                value: '${stats.membersInArrearsCount}',
                subtitle: stats.membersInArrearsCount > 0
                    ? 'Action needed'
                    : l10n.goodStanding,
                accentColor: stats.membersInArrearsCount > 0
                    ? AppColors.error
                    : AppColors.success,
                onTap: onViewMembers,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: Icons.assignment_late_outlined,
                title: l10n.pendingClaims,
                value: '${stats.pendingClaimsCount}',
                subtitle: stats.pendingClaimsCount > 0
                    ? 'Review queue'
                    : 'All clear',
                accentColor: AppColors.secondary,
                onTap: onViewClaims,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: accentColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Member Personal Financial Standing Card
// ─────────────────────────────────────────────────────────────────────────────

class _MemberPersonalStandingCard extends StatelessWidget {
  const _MemberPersonalStandingCard({
    required this.stats,
    required this.l10n,
    required this.onViewReceipts,
  });

  final MemberPersonalDashboard stats;
  final AppLocalizations l10n;
  final VoidCallback onViewReceipts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inArrears = stats.isInArrears;
    final accentColor = inArrears ? AppColors.warning : AppColors.success;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      inArrears ? Icons.warning_amber_rounded : Icons.check_circle,
                      color: accentColor,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.myFinancialStanding,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    inArrears ? l10n.arrears : l10n.goodStanding,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (inArrears) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.youAreInArrears(
                          stats.arrearsMonths,
                          stats.personalArrears,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.thumb_up_alt_outlined,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.youAreUpToDate,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Financial Metrics breakdown
            Row(
              children: [
                Expanded(
                  child: _MemberDataBox(
                    label: l10n.balance,
                    value: 'ETB ${stats.personalBalance.toStringAsFixed(0)}',
                    textColor: stats.personalBalance >= 0
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MemberDataBox(
                    label: l10n.totalPaidLabel,
                    value: 'ETB ${stats.totalPaid.toStringAsFixed(0)}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MemberDataBox(
                    label: l10n.monthlyDuesLabel,
                    value: 'ETB ${stats.monthlyDues.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewReceipts,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: Text(l10n.myContributions),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.reports),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Statement PDF'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberDataBox extends StatelessWidget {
  const _MemberDataBox({
    required this.label,
    required this.value,
    this.textColor,
  });

  final String label;
  final String value;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions Grid (Tailored by Role)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.userRole,
    required this.l10n,
    required this.onRecordPayment,
    this.onInviteMember,
    this.isDraft = false,
  });

  final UserRole userRole;
  final AppLocalizations l10n;
  final VoidCallback onRecordPayment;
  final VoidCallback? onInviteMember;
  final bool isDraft;

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = [];

    switch (userRole) {
      case UserRole.treasurer:
        actions.addAll([
          _ActionTile(
            icon: Icons.add_card,
            label: l10n.actionRecordPayment,
            color: AppColors.secondary,
            onTap: onRecordPayment,
            isLocked: isDraft,
          ),
          _ActionTile(
            icon: Icons.email_outlined,
            label: 'Invite Member',
            color: AppColors.primary,
            onTap: onInviteMember ?? () {},
          ),
          _ActionTile(
            icon: Icons.assignment_outlined,
            label: l10n.reviewClaims,
            color: const Color(0xFF1565C0),
            onTap: () => context.go(AppRoutes.claims),
            isLocked: isDraft,
          ),
          _ActionTile(
            icon: Icons.bar_chart_outlined,
            label: l10n.actionViewReports,
            color: const Color(0xFF5D4037),
            onTap: () => context.push(AppRoutes.reports),
          ),
        ]);
      case UserRole.chairperson:
        actions.addAll([
          _ActionTile(
            icon: Icons.email_outlined,
            label: 'Invite Member',
            color: AppColors.primary,
            onTap: onInviteMember ?? () {},
          ),
          _ActionTile(
            icon: Icons.fact_check_outlined,
            label: l10n.reviewClaims,
            color: AppColors.secondary,
            onTap: () => context.go(AppRoutes.claims),
            isLocked: isDraft,
          ),
          _ActionTile(
            icon: Icons.campaign_outlined,
            label: l10n.announcements,
            color: const Color(0xFFE65100),
            onTap: () => context.push(AppRoutes.announcements),
          ),
          _ActionTile(
            icon: Icons.bar_chart_outlined,
            label: l10n.actionViewReports,
            color: const Color(0xFF1565C0),
            onTap: () => context.push(AppRoutes.reports),
          ),
        ]);
      case UserRole.auditor:
        actions.addAll([
          _ActionTile(
            icon: Icons.security_outlined,
            label: l10n.actionViewAuditLog,
            color: const Color(0xFFC62828),
            onTap: () => context.push(AppRoutes.auditLog),
          ),
          _ActionTile(
            icon: Icons.bar_chart_outlined,
            label: l10n.actionViewReports,
            color: AppColors.primary,
            onTap: () => context.push(AppRoutes.reports),
          ),
          _ActionTile(
            icon: Icons.people_outline,
            label: l10n.membersTitle,
            color: const Color(0xFF1565C0),
            onTap: () => context.go(AppRoutes.members),
          ),
          _ActionTile(
            icon: Icons.receipt_long_outlined,
            label: l10n.contributionsTitle,
            color: AppColors.secondary,
            onTap: () => context.go(AppRoutes.contributions),
            isLocked: isDraft,
          ),
        ]);
      case UserRole.member:
        actions.addAll([
          _ActionTile(
            icon: Icons.post_add,
            label: l10n.actionSubmitClaim,
            color: AppColors.primary,
            onTap: () => context.go(AppRoutes.claims),
            isLocked: isDraft,
          ),
          _ActionTile(
            icon: Icons.receipt_long,
            label: l10n.myContributions,
            color: AppColors.secondary,
            onTap: () => context.go(AppRoutes.contributions),
            isLocked: isDraft,
          ),
          _ActionTile(
            icon: Icons.campaign_outlined,
            label: l10n.announcements,
            color: const Color(0xFF1565C0),
            onTap: () => context.push(AppRoutes.announcements),
          ),
          _ActionTile(
            icon: Icons.manage_accounts_outlined,
            label: l10n.account,
            color: const Color(0xFF455A64),
            onTap: () => context.push(AppRoutes.account),
          ),
        ]);
    }

    return Row(
      children: actions
          .map((tile) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: tile,
                ),
              ))
          .toList(),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLocked = false,
  });

  static const String _lockedMessage = 'Available once this Idir is active';

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = isLocked ? theme.colorScheme.onSurface.withValues(alpha: 0.38) : color;

    return InkWell(
      onTap: () {
        if (isLocked) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text(_lockedMessage)),
                ],
              ),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          onTap();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isLocked
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLocked
                ? theme.dividerColor.withValues(alpha: 0.25)
                : color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                        : color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: effectiveColor, size: 20),
                ),
                if (isLocked)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: isLocked
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                    : null,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Officer Activity Feed
// ─────────────────────────────────────────────────────────────────────────────

class _OfficerActivityFeed extends StatelessWidget {
  const _OfficerActivityFeed({required this.activities, required this.l10n});

  final List<DashboardActivityItem> activities;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            l10n.noRecentActivity,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
        itemBuilder: (context, index) {
          final act = activities[index];
          final timeStr = DateFormat('dd MMM, HH:mm').format(act.timestamp);

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: act.iconColor.withValues(alpha: 0.14),
              child: Icon(act.icon, size: 18, color: act.iconColor),
            ),
            title: Text(
              act.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${act.subtitle} • $timeStr',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: act.amount != null
                ? Text(
                    act.type == ActivityType.reversal
                        ? '-${act.amount!.toStringAsFixed(0)} ETB'
                        : '+${act.amount!.toStringAsFixed(0)} ETB',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: act.type == ActivityType.reversal
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Member Personal Recent Receipts
// ─────────────────────────────────────────────────────────────────────────────

class _MemberRecentReceiptsList extends StatelessWidget {
  const _MemberRecentReceiptsList({
    required this.receipts,
    required this.l10n,
  });

  final List<Contribution> receipts;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (receipts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            l10n.noRecentActivity,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: receipts.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
        itemBuilder: (context, index) {
          final r = receipts[index];
          final dateStr = DateFormat('dd MMM yyyy').format(r.date);

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.success.withValues(alpha: 0.12),
              child: const Icon(
                Icons.check,
                size: 18,
                color: AppColors.success,
              ),
            ),
            title: Text(
              '${r.receiptNumber} (${r.periodMonth}/${r.periodYear})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${r.paymentMethod.name.toUpperCase()} • $dateStr',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            trailing: Text(
              'ETB ${r.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          );
        },
      ),
    );
  }
}
