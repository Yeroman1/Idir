import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../invitations/presentation/providers/invitations_provider.dart';
import '../../domain/models/app_notification.dart';
import '../providers/notifications_provider.dart';

class NotificationsSheet extends ConsumerWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notificationsAsync = ref.watch(notificationsNotifierProvider);
    final invitationsAsync = ref.watch(receivedInvitationsProvider);
    final pendingInvites = invitationsAsync.value ?? [];

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_outlined, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Notifications',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    ref.read(notificationsNotifierProvider.notifier).markAllRead();
                  },
                  child: const Text('Mark all as read'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: notificationsAsync.when(
              data: (notifications) {
                if (notifications.isEmpty && pendingInvites.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "You're all caught up!",
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Invitations and updates will appear here directly.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    // Pending invitations highlight if available
                    if (pendingInvites.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(
                          'PENDING INVITATIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      ...pendingInvites.map((inv) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.25),
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
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.mail_outline_rounded,
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
                                            inv.idirName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Invited by ${inv.invitedBy}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.65),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (inv.contributionAmount != null) ...[
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 44),
                                    child: Text(
                                      'Contribution: ${inv.contributionAmount!.toStringAsFixed(0)} ETB (${inv.contributionFrequency ?? 'Monthly'})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                                        final success = await ref
                                            .read(receivedInvitationsProvider.notifier)
                                            .respond(inv.id, 'REJECT');
                                        ref.invalidate(notificationsNotifierProvider);
                                        if (context.mounted) {
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content: Text(success
                                                  ? 'Invitation to join ${inv.idirName} rejected.'
                                                  : 'Failed to process response.'),
                                              backgroundColor: AppColors.secondary,
                                            ),
                                          );
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: theme.colorScheme.error,
                                        side: BorderSide(
                                            color: theme.colorScheme.error.withValues(alpha: 0.4)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(Icons.close, size: 14),
                                      label: const Text('Reject', style: TextStyle(fontSize: 12)),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: () async {
                                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                                        final success = await ref
                                            .read(receivedInvitationsProvider.notifier)
                                            .respond(inv.id, 'ACCEPT', targetIdirId: inv.idirId);
                                        ref.invalidate(notificationsNotifierProvider);
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content: Text(success
                                                  ? 'Welcome! You have successfully joined ${inv.idirName}.'
                                                  : 'Failed to join Idir. Please try again.'),
                                              backgroundColor: AppColors.success,
                                            ),
                                          );
                                        }
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(Icons.check, size: 14),
                                      label: const Text('Accept', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                    ],

                    if (notifications.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(
                          'ALL NOTIFICATIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      ...notifications.map((notif) => _NotificationTile(
                            notification: notif,
                            onTap: () {
                              if (!notif.isRead) {
                                ref
                                    .read(notificationsNotifierProvider.notifier)
                                    .markRead(notif.id);
                              }
                            },
                          )),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Unable to load notifications: $err'),
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;
    final isInvite = notification.isInvitation;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUnread
            ? (isInvite
                ? AppColors.primary.withValues(alpha: 0.05)
                : theme.colorScheme.surfaceVariant.withValues(alpha: 0.35))
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? (isInvite
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : theme.dividerColor)
              : theme.dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isInvite
                ? AppColors.primary.withValues(alpha: 0.12)
                : theme.colorScheme.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isInvite ? Icons.mail_outline_rounded : Icons.notifications_outlined,
            color: isInvite ? AppColors.primary : theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              notification.body,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, h:mm a').format(notification.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        trailing: isUnread
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }
}
