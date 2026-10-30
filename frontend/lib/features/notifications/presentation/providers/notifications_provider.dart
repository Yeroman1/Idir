import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../invitations/presentation/providers/invitations_provider.dart';
import '../../data/notifications_repository.dart';
import '../../domain/models/app_notification.dart';

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
