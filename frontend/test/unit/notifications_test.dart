import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:idir_app/features/invitations/domain/models/received_invitation.dart';
import 'package:idir_app/features/invitations/presentation/providers/invitations_provider.dart';
import 'package:idir_app/features/notifications/data/notifications_repository.dart';
import 'package:idir_app/features/notifications/domain/models/app_notification.dart';
import 'package:idir_app/features/notifications/domain/models/notification_preferences.dart';
import 'package:idir_app/features/notifications/domain/models/notification_filter.dart';
import 'package:idir_app/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:idir_app/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:idir_app/features/notifications/presentation/screens/notification_preferences_screen.dart';

class MockNotificationsRepository implements NotificationsRepository {
  List<AppNotification> items = [];
  bool markAsReadCalled = false;
  bool markAllAsReadCalled = false;
  NotificationPreferences? preferences = const NotificationPreferences();

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

  @override
  Future<NotificationPreferences?> getPreferences() async {
    return preferences;
  }

  @override
  Future<bool> updatePreferences(NotificationPreferences prefs) async {
    preferences = prefs;
    return true;
  }

  @override
  Future<bool> registerDeviceToken(String token, {String platform = 'android'}) async {
    return true;
  }

  @override
  Future<bool> unregisterDeviceToken(String token) async {
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

    test('AppNotification helpers identify contribution, meeting, ikub, governance, urgent', () {
      final meetingNotif = AppNotification(
        id: '1',
        title: 'Meeting Scheduled',
        body: 'Details',
        type: 'MEETING_REMINDER',
        data: const {'meetingId': 'm-1'},
        createdAt: DateTime.now(),
      );
      expect(meetingNotif.isMeeting, isTrue);
      expect(meetingNotif.meetingId, 'm-1');

      final contribNotif = AppNotification(
        id: '2',
        title: 'Contribution Due',
        body: 'Pay 100 ETB',
        type: 'PAYMENT_DUE',
        data: const {'periodMonth': 11, 'periodYear': 2026},
        createdAt: DateTime.now(),
      );
      expect(contribNotif.isContribution, isTrue);

      final govNotif = AppNotification(
        id: '3',
        title: 'Leadership Election',
        body: 'Voting open',
        type: 'GOVERNANCE',
        data: const {'electionId': 'el-1'},
        createdAt: DateTime.now(),
      );
      expect(govNotif.isGovernance, isTrue);
      expect(govNotif.electionId, 'el-1');

      final urgentNotif = AppNotification(
        id: '4',
        title: 'Emergency Alert',
        body: 'Urgent notice',
        type: 'URGENT_ALERT',
        createdAt: DateTime.now(),
      );
      expect(urgentNotif.isUrgent, isTrue);
    });

    test('NotificationPreferences serialization, copyWith, and defaults', () {
      const defaultPrefs = NotificationPreferences();
      expect(defaultPrefs.inAppEnabled, isTrue);
      expect(defaultPrefs.pushEnabled, isTrue);
      expect(defaultPrefs.quietHoursEnabled, isFalse);

      final map = {
        'inAppEnabled': false,
        'pushEnabled': true,
        'smsEnabled': false,
        'emailEnabled': true,
        'reminderMeetings': false,
        'reminderContributions': true,
        'notifyAnnouncements': true,
        'notifyGovernance': false,
        'notifyAssistance': true,
        'quietHoursEnabled': true,
        'quietHoursStart': '23:30',
        'quietHoursEnd': '06:30',
      };

      final parsed = NotificationPreferences.fromMap(map);
      expect(parsed.inAppEnabled, isFalse);
      expect(parsed.reminderMeetings, isFalse);
      expect(parsed.quietHoursEnabled, isTrue);
      expect(parsed.quietHoursStart, '23:30');

      final updated = parsed.copyWith(inAppEnabled: true);
      expect(updated.inAppEnabled, isTrue);
      expect(updated.quietHoursStart, '23:30');
    });

    test('NotificationPreferencesNotifier loads and updates preferences', () async {
      final repo = MockNotificationsRepository();
      repo.preferences = const NotificationPreferences(
        inAppEnabled: true,
        pushEnabled: false,
      );

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

      final notifier = container.read(notificationPreferencesNotifierProvider.notifier);
      await notifier.loadPreferences();

      final state = container.read(notificationPreferencesNotifierProvider);
      expect(state.value?.pushEnabled, isFalse);

      // Update preferences
      final newPrefs = state.value!.copyWith(pushEnabled: true);
      await notifier.updatePreferences(newPrefs);

      final updatedState = container.read(notificationPreferencesNotifierProvider);
      expect(updatedState.value?.pushEnabled, isTrue);
      expect(repo.preferences?.pushEnabled, isTrue);
    });

    test('filteredNotificationsProvider correctly filters by category', () async {
      final repo = MockNotificationsRepository();
      repo.items = [
        AppNotification(
          id: '1',
          title: 'Meeting 1',
          body: 'Details',
          type: 'MEETING_REMINDER',
          createdAt: DateTime.now(),
        ),
        AppNotification(
          id: '2',
          title: 'Contribution 1',
          body: 'Details',
          type: 'PAYMENT_DUE',
          readAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        AppNotification(
          id: '3',
          title: 'Announcement 1',
          body: 'Details',
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

      await container.read(notificationsNotifierProvider.notifier).loadNotifications();

      // All
      expect(container.read(filteredNotificationsProvider).value?.length, 3);

      // Unread only (item 1 and 3)
      container.read(notificationFilterProvider.notifier).state = NotificationCategoryFilter.unread;
      expect(container.read(filteredNotificationsProvider).value?.length, 2);

      // Meetings only (item 1)
      container.read(notificationFilterProvider.notifier).state = NotificationCategoryFilter.meetings;
      expect(container.read(filteredNotificationsProvider).value?.length, 1);
      expect(container.read(filteredNotificationsProvider).value?.first.id, '1');

      // Contributions only (item 2)
      container.read(notificationFilterProvider.notifier).state = NotificationCategoryFilter.contributions;
      expect(container.read(filteredNotificationsProvider).value?.length, 1);
      expect(container.read(filteredNotificationsProvider).value?.first.id, '2');
    });

    testWidgets('NotificationCenterScreen renders notification list and filter chips', (tester) async {
      final repo = MockNotificationsRepository();
      repo.items = [
        AppNotification(
          id: 'n-1',
          title: 'Annual Assembly Scheduled',
          body: 'Join the annual meeting at the community center',
          type: 'MEETING_REMINDER',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
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
          child: const MaterialApp(
            home: NotificationCenterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notification Center'), findsOneWidget);
      expect(find.text('Annual Assembly Scheduled'), findsOneWidget);
      expect(find.text('Meetings'), findsOneWidget);
      expect(find.text('Contributions'), findsOneWidget);
    });

    testWidgets('NotificationPreferencesScreen renders delivery channels and quiet hours', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockNotificationsRepository();
      repo.preferences = const NotificationPreferences(
        inAppEnabled: true,
        pushEnabled: true,
        quietHoursEnabled: true,
        quietHoursStart: '22:00',
        quietHoursEnd: '07:00',
      );

      await tester.pumpWidget(
        ProviderScope(
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
          child: const MaterialApp(
            home: NotificationPreferencesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notification Preferences'), findsOneWidget);
      expect(find.text('In-App Notifications'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Contribution Reminders'), findsOneWidget);
      expect(find.text('Enable Quiet Hours'), findsOneWidget);
    });
  });
}

