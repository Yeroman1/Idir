import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../invitations/domain/models/received_invitation.dart';
import '../../../invitations/presentation/providers/invitations_provider.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/notification_filter.dart';
import '../providers/notifications_provider.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final selectedFilter = ref.watch(notificationFilterProvider);
    final notificationsAsync = ref.watch(filteredNotificationsProvider);
    final invitationsAsync = ref.watch(receivedInvitationsProvider);
    final pendingInvites = invitationsAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center'),
        centerTitle: false,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                ref.read(notificationsNotifierProvider.notifier).markAllRead();
              },
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read'),
            ),
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Notification Preferences',
            onPressed: () {
              context.push('/settings/notifications');
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(
                  context,
                  ref,
                  label: 'All',
                  filter: NotificationCategoryFilter.all,
                  isSelected: selectedFilter == NotificationCategoryFilter.all,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  ref,
                  label: unreadCount > 0 ? 'Unread ($unreadCount)' : 'Unread',
                  filter: NotificationCategoryFilter.unread,
                  isSelected: selectedFilter == NotificationCategoryFilter.unread,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  ref,
                  label: 'Contributions',
                  filter: NotificationCategoryFilter.contributions,
                  isSelected: selectedFilter == NotificationCategoryFilter.contributions,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  ref,
                  label: 'Meetings',
                  filter: NotificationCategoryFilter.meetings,
                  isSelected: selectedFilter == NotificationCategoryFilter.meetings,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  ref,
                  label: 'Announcements',
                  filter: NotificationCategoryFilter.announcements,
                  isSelected: selectedFilter == NotificationCategoryFilter.announcements,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  ref,
                  label: pendingInvites.isNotEmpty
                      ? 'Invitations (${pendingInvites.length})'
                      : 'Invitations',
                  filter: NotificationCategoryFilter.invitations,
                  isSelected: selectedFilter == NotificationCategoryFilter.invitations,
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(notificationsNotifierProvider.notifier).loadNotifications();
          ref.invalidate(receivedInvitationsProvider);
        },
        child: notificationsAsync.when(
          data: (notifications) {
            final showInvites = (selectedFilter == NotificationCategoryFilter.all ||
                    selectedFilter == NotificationCategoryFilter.invitations) &&
                pendingInvites.isNotEmpty;

            if (notifications.isEmpty && !showInvites) {
              return _buildEmptyState(context, selectedFilter);
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (showInvites) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8, left: 4),
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
                  ...pendingInvites.map((inv) => _buildInvitationCard(context, ref, inv)),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                ],
                if (notifications.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      'RECENT NOTIFICATIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  ...notifications.map((n) => _buildNotificationTile(context, ref, n)),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Failed to load notifications: $err'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(notificationsNotifierProvider.notifier).loadNotifications();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required NotificationCategoryFilter filter,
    required bool isSelected,
  }) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) {
        ref.read(notificationFilterProvider.notifier).state = filter;
      },
    );
  }

  Widget _buildInvitationCard(BuildContext context, WidgetRef ref, ReceivedInvitation inv) {
    final theme = Theme.of(context);

    return Container(
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Invited by ${inv.invitedBy}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await ref
                      .read(receivedInvitationsProvider.notifier)
                      .respond(inv.id, 'REJECT');
                  ref.invalidate(notificationsNotifierProvider);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Invitation rejected.'
                          : 'Failed to process response.'),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.close, size: 14),
                label: const Text('Reject', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await ref
                      .read(receivedInvitationsProvider.notifier)
                      .respond(inv.id, 'ACCEPT', targetIdirId: inv.idirId);
                  ref.invalidate(notificationsNotifierProvider);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Welcome! You have joined ${inv.idirName}.'
                          : 'Failed to join Idir.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    Color iconColor = AppColors.primary;
    IconData iconData = Icons.notifications_outlined;

    if (notification.isContribution) {
      iconColor = Colors.teal;
      iconData = Icons.account_balance_wallet_outlined;
    } else if (notification.isMeeting) {
      iconColor = Colors.blue;
      iconData = Icons.calendar_today_outlined;
    } else if (notification.isIkub) {
      iconColor = Colors.deepPurple;
      iconData = Icons.sync_rounded;
    } else if (notification.isGovernance) {
      iconColor = Colors.deepOrange;
      iconData = Icons.how_to_vote_outlined;
    } else if (notification.isAssistance) {
      iconColor = Colors.indigo;
      iconData = Icons.medical_services_outlined;
    } else if (notification.isUrgent) {
      iconColor = Colors.red;
      iconData = Icons.warning_amber_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUnread
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread ? iconColor.withValues(alpha: 0.25) : theme.dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          onTap: () {
            if (!notification.isRead) {
              ref.read(notificationsNotifierProvider.notifier).markRead(notification.id);
            }
            _handleNotificationNavigation(context, notification);
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 20),
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
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  void _handleNotificationNavigation(BuildContext context, AppNotification n) {
    if (n.isContribution) {
      context.push('/contributions');
    } else if (n.isMeeting) {
      context.push('/meetings');
    } else if (n.isIkub) {
      context.push('/ikub');
    } else if (n.isGovernance) {
      context.push('/elections');
    } else {
      // Show detail dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(n.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.body),
              const SizedBox(height: 12),
              Text(
                DateFormat('EEEE, MMMM d, yyyy h:mm a').format(n.createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildEmptyState(BuildContext context, NotificationCategoryFilter filter) {
    final theme = Theme.of(context);
    String message = "You're all caught up!";
    if (filter == NotificationCategoryFilter.unread) {
      message = 'No unread notifications';
    } else if (filter == NotificationCategoryFilter.contributions) {
      message = 'No contribution notifications or reminders';
    } else if (filter == NotificationCategoryFilter.meetings) {
      message = 'No meeting reminders scheduled';
    }

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
              message,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upcoming community activities and reminders will be listed here.',
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
}
