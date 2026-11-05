import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../invitations/presentation/providers/invitations_provider.dart';
import '../../data/notifications_repository.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/notification_preferences.dart';
import '../../domain/models/notification_filter.dart';

class NotificationsNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  NotificationsNotifier(this._repository, [this._userId])
      : super(const AsyncValue.loading()) {
    if (_userId == null) {
      state = const AsyncValue.data([]);
    } else {
      loadNotifications();
    }
  }

  final NotificationsRepository _repository;
  final String? _userId;

  Future<void> loadNotifications() async {
    if (_userId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final list = await _repository.getNotifications();
      state = AsyncValue.data(list);
    } catch (e, st) {
      debugPrint('[NotificationsNotifier] loadNotifications error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markRead(String notificationId) async {
    final currentList = state.value ?? [];
    // Optimistically update
    state = AsyncValue.data(
      currentList.map((n) {
        if (n.id == notificationId) {
          return AppNotification(
            id: n.id,
            title: n.title,
            body: n.body,
            type: n.type,
            data: n.data,
            readAt: DateTime.now(),
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList(),
    );

    await _repository.markAsRead(notificationId);
  }

  Future<void> markAllRead() async {
    final currentList = state.value ?? [];
    final now = DateTime.now();
    state = AsyncValue.data(
      currentList.map((n) {
        return AppNotification(
          id: n.id,
          title: n.title,
          body: n.body,
          type: n.type,
          data: n.data,
          readAt: n.readAt ?? now,
          createdAt: n.createdAt,
        );
      }).toList(),
    );

    await _repository.markAllAsRead();
  }
}

final notificationsNotifierProvider = StateNotifierProvider.autoDispose<
    NotificationsNotifier, AsyncValue<List<AppNotification>>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repo = ref.watch(notificationsRepositoryProvider);
  return NotificationsNotifier(repo, user?.uid);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifsAsync = ref.watch(notificationsNotifierProvider);
  return notifsAsync.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

final totalPendingAlertsCountProvider = Provider<int>((ref) {
  final unreadNotifs = ref.watch(unreadNotificationCountProvider);
  final invitationsAsync = ref.watch(receivedInvitationsProvider);
  final pendingInvites = invitationsAsync.maybeWhen(
    data: (list) => list.length,
    orElse: () => 0,
  );
  return unreadNotifs > pendingInvites ? unreadNotifs : pendingInvites;
});

final notificationFilterProvider =
    StateProvider<NotificationCategoryFilter>((ref) => NotificationCategoryFilter.all);

final filteredNotificationsProvider =
    Provider<AsyncValue<List<AppNotification>>>((ref) {
  final notifsAsync = ref.watch(notificationsNotifierProvider);
  final filter = ref.watch(notificationFilterProvider);

  return notifsAsync.whenData((list) {
    switch (filter) {
      case NotificationCategoryFilter.all:
        return list;
      case NotificationCategoryFilter.unread:
        return list.where((n) => !n.isRead).toList();
      case NotificationCategoryFilter.contributions:
        return list.where((n) => n.isContribution).toList();
      case NotificationCategoryFilter.meetings:
        return list.where((n) => n.isMeeting).toList();
      case NotificationCategoryFilter.announcements:
        return list
            .where((n) =>
                n.type == 'ANNOUNCEMENT' || n.isUrgent || (!n.isMeeting && !n.isContribution && !n.isInvitation))
            .toList();
      case NotificationCategoryFilter.invitations:
        return list.where((n) => n.isInvitation).toList();
    }
  });
});

class NotificationPreferencesNotifier
    extends StateNotifier<AsyncValue<NotificationPreferences>> {
  NotificationPreferencesNotifier(this._repository, [this._userId])
      : super(const AsyncValue.loading()) {
    if (_userId == null) {
      state = const AsyncValue.data(NotificationPreferences());
    } else {
      loadPreferences();
    }
  }

  final NotificationsRepository _repository;
  final String? _userId;

  Future<void> loadPreferences() async {
    if (_userId == null) {
      state = const AsyncValue.data(NotificationPreferences());
      return;
    }
    state = const AsyncValue.loading();
    try {
      final prefs = await _repository.getPreferences();
      state = AsyncValue.data(prefs ?? const NotificationPreferences());
    } catch (e, st) {
      debugPrint('[NotificationPreferencesNotifier] loadPreferences error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> updatePreferences(NotificationPreferences prefs) async {
    // Optimistic update
    state = AsyncValue.data(prefs);
    try {
      final success = await _repository.updatePreferences(prefs);
      if (!success) {
        // Reload from server on failure
        await loadPreferences();
      }
      return success;
    } catch (e, st) {
      debugPrint('[NotificationPreferencesNotifier] updatePreferences error: $e');
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final notificationPreferencesNotifierProvider = StateNotifierProvider.autoDispose<
    NotificationPreferencesNotifier, AsyncValue<NotificationPreferences>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repo = ref.watch(notificationsRepositoryProvider);
  return NotificationPreferencesNotifier(repo, user?.uid);
});
