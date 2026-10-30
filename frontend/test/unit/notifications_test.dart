import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:idir_app/features/invitations/domain/models/received_invitation.dart';
import 'package:idir_app/features/invitations/presentation/providers/invitations_provider.dart';
import 'package:idir_app/features/notifications/data/notifications_repository.dart';
import 'package:idir_app/features/notifications/domain/models/app_notification.dart';
import 'package:idir_app/features/notifications/presentation/providers/notifications_provider.dart';

class MockNotificationsRepository implements NotificationsRepository {
  List<AppNotification> items = [];
  bool markAsReadCalled = false;
  bool markAllAsReadCalled = false;

  @override
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    return items;
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    markAsReadCalled = true;
    items = items.map((n) {
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
    }).toList();
    return true;
  }

  @override
  Future<bool> markAllAsRead() async {
    markAllAsReadCalled = true;
    final now = DateTime.now();
    items = items.map((n) {
      return AppNotification(
        id: n.id,
        title: n.title,
        body: n.body,
        type: n.type,
        data: n.data,
        readAt: n.readAt ?? now,
        createdAt: n.createdAt,
      );
    }).toList();
    return true;
  }
}

void main() {
  group('Notifications Unit Tests', () {
    test('AppNotification correctly parses invitation notification payload', () {
      final map = {
        'id': 'notif-101',
        'title': 'Invitation from Bole Medhanealem Idir',
        'body': 'Abebe invited you to join Bole Medhanealem Idir.',
        'type': 'ANNOUNCEMENT',
        'data': {
          'type': 'INVITATION',
          'invitationId': 'inv-555',
          'idirId': 'idir-001',
          'idirName': 'Bole Medhanealem Idir',
        },
        'readAt': null,
        'createdAt': '2026-10-30T10:00:00.000Z',
      };

      final notif = AppNotification.fromMap(map);
      expect(notif.id, 'notif-101');
      expect(notif.title, 'Invitation from Bole Medhanealem Idir');
      expect(notif.isRead, isFalse);
      expect(notif.isInvitation, isTrue);
      expect(notif.invitationId, 'inv-555');
      expect(notif.idirId, 'idir-001');
      expect(notif.idirName, 'Bole Medhanealem Idir');
    });

    test('NotificationsNotifier loads notifications and marks individual notification as read', () async {
      final repo = MockNotificationsRepository();
      repo.items = [
        AppNotification(
          id: 'n-1',
          title: 'Invitation from Yeka Idir',
          body: 'You received an invitation',
          type: 'ANNOUNCEMENT',
          data: const {'type': 'INVITATION', 'invitationId': 'inv-1'},
          readAt: null,
          createdAt: DateTime.now(),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(
            AppUser(
              uid: 'user-rec-1',
              name: 'Receiver User',
              phone: '+251911999999',
              role: UserRole.member,
              memberId: 'M-001',
              isActive: true,
              createdAt: DateTime(2026),
            ),
          ),
          notificationsRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final notifier = container.read(notificationsNotifierProvider.notifier);
      await notifier.loadNotifications();

      final state = container.read(notificationsNotifierProvider);
      expect(state.value?.length, 1);
      expect(state.value?.first.isRead, isFalse);
      expect(container.read(unreadNotificationCountProvider), 1);

      // Mark as read
      await notifier.markRead('n-1');
      expect(repo.markAsReadCalled, isTrue);

      final updatedState = container.read(notificationsNotifierProvider);
      expect(updatedState.value?.first.isRead, isTrue);
      expect(container.read(unreadNotificationCountProvider), 0);
    });

    test('NotificationsNotifier markAllRead marks all notifications as read', () async {
      final repo = MockNotificationsRepository();
      repo.items = [
        AppNotification(
          id: 'n-1',
          title: 'Notif 1',
          body: 'Body 1',
          type: 'ANNOUNCEMENT',
          createdAt: DateTime.now(),
        ),
        AppNotification(
          id: 'n-2',
          title: 'Notif 2',
          body: 'Body 2',
          type: 'ANNOUNCEMENT',
          createdAt: DateTime.now(),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(
            AppUser(
              uid: 'user-rec-1',
              name: 'Receiver User',
              phone: '+251911999999',
              role: UserRole.member,
              memberId: 'M-001',
              isActive: true,
              createdAt: DateTime(2026),
            ),
          ),
          notificationsRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final notifier = container.read(notificationsNotifierProvider.notifier);
      await notifier.loadNotifications();
      expect(container.read(unreadNotificationCountProvider), 2);

      await notifier.markAllRead();
      expect(repo.markAllAsReadCalled, isTrue);
      expect(container.read(unreadNotificationCountProvider), 0);
    });
  });
}

