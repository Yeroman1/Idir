import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final role = user?.role ?? UserRole.member;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moreTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Account & Profile Banner ───────────────────────────────────
          if (user != null)
            ListTile(
              leading: CircleAvatar(
                child: Text(user.name.isNotEmpty ? user.name[0] : 'U'),
              ),
              title: Text(user.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(user.role.name.toUpperCase()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.account),
            ),
          const Divider(height: 16),

          // ── Features ───────────────────────────────────────────────────
          _MoreItem(
            Icons.forum_outlined,
            l10n.groupChatTitle,
            () => context.push(AppRoutes.chat),
          ),
          _MoreItem(
            Icons.campaign_outlined,
            l10n.announcements,
            () => context.push(AppRoutes.announcements),
          ),
          _MoreItem(
            Icons.how_to_vote_outlined,
            'Leadership Elections',
            () => context.push(AppRoutes.elections),
          ),
          _MoreItem(
            Icons.bar_chart_outlined,
            role.canViewAllFinances ? l10n.reports : 'My Dues Statement',
            () => context.push(AppRoutes.reports),
          ),
          if (role.canViewAllFinances)
            _MoreItem(
              Icons.receipt_long_outlined,
              l10n.expenses,
              () => context.push(AppRoutes.expenses),
            ),
          if (role.canViewAuditLog)
            _MoreItem(
              Icons.security_outlined,
              l10n.auditLog,
              () => context.push(AppRoutes.auditLog),
            ),
          if (role.canChangeSettings)
            _MoreItem(
              Icons.settings_outlined,
              l10n.settings,
              () => context.push(AppRoutes.settings),
            ),

          const Divider(height: 16),

          _MoreItem(
            Icons.person_outline,
            l10n.account,
            () => context.push(AppRoutes.account),
          ),
          _MoreItem(
            Icons.logout,
            l10n.logout,
            () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _MoreItem extends StatelessWidget {
  const _MoreItem(this.icon, this.label, this.onTap,
      {this.isDestructive = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      minVerticalPadding: 16,
    );
  }
}
