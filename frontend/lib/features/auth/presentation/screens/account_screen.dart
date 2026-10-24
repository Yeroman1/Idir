import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/providers/pin_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/providers/dashboard_provider.dart';
import '../providers/auth_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  void _showEditProfileSheet(BuildContext context, WidgetRef ref, AppUser user) {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          top: 16,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Edit Account Profile',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Update your official name and registered phone number.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final newName = nameCtrl.text.trim();
                      final newPhone = phoneCtrl.text.trim();
                      if (newName.isNotEmpty) {
                        await ref.read(authNotifierProvider.notifier).updateProfile(
                              name: newName,
                              phone: newPhone,
                            );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully!'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final pinState = ref.watch(pinNotifierProvider);
    final memberStats = ref.watch(memberPersonalDashboardProvider);
    final df = DateFormat('dd MMM yyyy');

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.account)),
        body: Center(
          child: ElevatedButton(
            onPressed: () => context.go(AppRoutes.login),
            child: Text(l10n.loginButton),
          ),
        ),
      );
    }

    final roleLabel = switch (user.role) {
      UserRole.chairperson => l10n.roleChairperson,
      UserRole.treasurer => l10n.roleTreasurer,
      UserRole.auditor => l10n.roleAuditor,
      UserRole.member => l10n.roleMember,
    };

    final roleColor = switch (user.role) {
      UserRole.chairperson => AppColors.primary,
      UserRole.treasurer => AppColors.secondary,
      UserRole.auditor => const Color(0xFF1565C0),
      UserRole.member => const Color(0xFF4E7D6B),
    };

    final roleIcon = switch (user.role) {
      UserRole.chairperson => Icons.star_rounded,
      UserRole.treasurer => Icons.account_balance_wallet_rounded,
      UserRole.auditor => Icons.policy_rounded,
      UserRole.member => Icons.person_rounded,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.account),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditProfileSheet(context, ref, user),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── 1. Hero Profile Header Card ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  roleColor.withValues(alpha: 0.15),
                  roleColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: roleColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: roleColor.withValues(alpha: 0.2),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: roleColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(roleIcon, size: 14, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  user.phone.isNotEmpty ? user.phone : 'No phone linked',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: roleColor, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(roleIcon, size: 14, color: roleColor),
                      const SizedBox(width: 6),
                      Text(
                        roleLabel.toUpperCase(),
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),



          // ── 3. Personal Member Standing Card (Especially for Regular Member)
          if (user.role == UserRole.member) ...[
            const _SectionTitle(title: 'Personal Dues & Mutual Aid Standing'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (memberStats.isInArrears
                          ? AppColors.warning
                          : AppColors.success)
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Membership Standing',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            memberStats.isInArrears
                                ? 'Arrears (${memberStats.arrearsMonths} Months Overdue)'
                                : 'In Good Standing',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: memberStats.isInArrears
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (memberStats.isInArrears
                                  ? AppColors.error
                                  : AppColors.success)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          memberStats.isInArrears ? 'OVERDUE' : 'ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: memberStats.isInArrears
                                ? AppColors.error
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(
                        label: 'Total Paid',
                        value: '${memberStats.totalPaid.toStringAsFixed(0)} ETB',
                        color: AppColors.primary,
                      ),
                      _StatColumn(
                        label: 'Monthly Rate',
                        value: '${memberStats.monthlyDues.toStringAsFixed(0)} ETB',
                        color: AppColors.secondary,
                      ),
                      _StatColumn(
                        label: memberStats.isInArrears ? 'Arrears' : 'Advance',
                        value: memberStats.isInArrears
                            ? '${memberStats.personalArrears.toStringAsFixed(0)} ETB'
                            : '${memberStats.personalBalance.toStringAsFixed(0)} ETB',
                        color: memberStats.isInArrears
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long_outlined, size: 16),
                      label: const Text('View Official Receipts'),
                      onPressed: () => context.go(AppRoutes.contributions),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 4. Account & Membership Details Card ────────────────────────
          const _SectionTitle(title: 'Membership Registry Details'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(l10n.memberIdLabel),
                  subtitle: Text(
                    user.memberId.isNotEmpty ? user.memberId : 'IDIR-001',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(l10n.phoneLabel),
                  subtitle: Text(user.phone.isNotEmpty ? user.phone : '—'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _showEditProfileSheet(context, ref, user),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Registration Date'),
                  subtitle: Text(df.format(user.createdAt)),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(l10n.statusLabel),
                  subtitle: Text(
                    user.isActive ? 'Active Member • Verified' : 'Inactive',
                    style: TextStyle(
                      color: user.isActive ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 5. Security & PIN Card ───────────────────────────────────────
          const _SectionTitle(title: 'Security & PIN Protection'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: Text(pinState.isSet ? l10n.changePin : l10n.pinSetupTitle),
                  subtitle: Text(
                    pinState.isSet
                        ? '4-Digit PIN lock is active'
                        : 'PIN lock is disabled',
                    style: TextStyle(
                      color: pinState.isSet ? AppColors.success : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push(
                      pinState.isSet ? AppRoutes.pinChange : AppRoutes.pinSetup,
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                const ListTile(
                  leading: Icon(Icons.lock_clock_outlined),
                  title: Text('Session Inactivity Lock'),
                  subtitle: Text(
                    '2 minutes of idle time automatically locks the app',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 6. Sign Out Button ──────────────────────────────────────────
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.logout),
            label: Text(l10n.logout),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.logout),
                  content: Text(
                    'Are you sure you want to sign out of ${user.name}?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.cancel),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.confirm),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) {
                  context.go(AppRoutes.login);
                }
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
