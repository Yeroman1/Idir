import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/core/providers/sync_status_provider.dart';
import 'package:idir_app/core/providers/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SyncNotifier Unit Tests', () {
    late SyncNotifier notifier;

    setUp(() {
      notifier = SyncNotifier();
    });

    test('Initial state is synced and not simulated offline', () {
      expect(notifier.state.status, SyncStatus.synced);
      expect(notifier.state.isOffline, isFalse);
      expect(notifier.state.isSyncing, isFalse);
      expect(notifier.state.pendingCount, 0);
    });

    test('toggleOffline enables simulated offline mode and queues pending item', () {
      notifier.toggleOffline();

      expect(notifier.state.isOfflineSimulated, isTrue);
      expect(notifier.state.isOffline, isTrue);
      expect(notifier.state.status, SyncStatus.offline);
      expect(notifier.state.pendingCount, greaterThan(0));
    });

    test('enqueueItem adds new pending sync items correctly', () {
      notifier.enqueueItem(
        title: 'Bereavement Claim #CLM-909',
        type: 'Claim',
      );

      expect(notifier.state.pendingCount, 1);
      final item = notifier.state.pendingQueue.first;
      expect(item.title, 'Bereavement Claim #CLM-909');
      expect(item.type, 'Claim');
    });

    test('clearPendingQueue empties pending changes', () {
      notifier.enqueueItem(
        title: 'Monthly Dues ETB 200',
        type: 'Contribution',
      );
      expect(notifier.state.pendingCount, 1);

      notifier.clearPendingQueue();
      expect(notifier.state.pendingCount, 0);
    });

    test('triggerSync synchronizes offline queue and clears pending list', () async {
      notifier.enqueueItem(
        title: 'Offline Dues Payment',
        type: 'Contribution',
      );
      expect(notifier.state.pendingCount, 1);

      await notifier.triggerSync();

      expect(notifier.state.status, SyncStatus.synced);
      expect(notifier.state.isOffline, isFalse);
      expect(notifier.state.pendingCount, 0);
      expect(notifier.state.isSyncing, isFalse);
    });
  });

  group('ThemeModeNotifier Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ThemeModeNotifier initial mode defaults to system', () {
      final notifier = ThemeModeNotifier();
      expect(notifier.state, ThemeMode.system);
    });

    test('setMode updates and persists ThemeMode.dark', () async {
      final notifier = ThemeModeNotifier();
      await notifier.setMode(ThemeMode.dark);

      expect(notifier.state, ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('setMode updates and persists ThemeMode.light', () async {
      final notifier = ThemeModeNotifier();
      await notifier.setMode(ThemeMode.light);

      expect(notifier.state, ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });
  });
}
