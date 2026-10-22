import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/core/providers/sync_status_provider.dart';
import 'package:idir_app/core/storage/offline_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OfflineCacheService & Resilience Tests', () {
    late OfflineCacheService cacheService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      cacheService = OfflineCacheService();
    });

    test('saves and reads cached JSON data with timestamps', () async {
      const key = 'test_contributions';
      final testData = [
        {
          'id': 'rec_101',
          'amount': 200.0,
          'receiptNumber': 'REC-2026-101',
          'memberName': 'Abebe Tadesse',
        }
      ];

      await cacheService.save(key, testData);

      final cached = await cacheService.read(key);
      expect(cached, isA<List<dynamic>>());
      final list = cached as List<dynamic>;
      expect(list.length, 1);
      final firstItem = list.first as Map<String, dynamic>;
      expect(firstItem['receiptNumber'], 'REC-2026-101');

      final cachedTime = await cacheService.getLastCachedTime(key);
      expect(cachedTime, isNotNull);
      expect(DateTime.now().difference(cachedTime!).inSeconds, lessThan(5));
    });

    test('has() correctly identifies cached keys', () async {
      expect(await cacheService.has('missing_key'), isFalse);
      await cacheService.save('existing_key', {'status': 'ok'});
      expect(await cacheService.has('existing_key'), isTrue);
    });

    test('remove() and clearAll() clear persistent cache', () async {
      await cacheService.save('k1', 'data1');
      await cacheService.save('k2', 'data2');

      await cacheService.remove('k1');
      expect(await cacheService.read('k1'), isNull);
      expect(await cacheService.read('k2'), isNotNull);

      await cacheService.clearAll();
      expect(await cacheService.read('k2'), isNull);
    });
  });

  group('SyncNotifier Network Resilience & Callbacks', () {
    late SyncNotifier notifier;

    setUp(() {
      notifier = SyncNotifier();
    });

    test('reportNetworkError switches status to offline', () {
      expect(notifier.state.isOffline, isFalse);
      notifier.reportNetworkError('Socket connection refused');

      expect(notifier.state.status, SyncStatus.offline);
      expect(notifier.state.isOffline, isTrue);
      expect(notifier.state.errorMessage, contains('refused'));
    });

    test('reportNetworkSuccess restores status to synced', () {
      notifier.reportNetworkError('Connection timeout');
      expect(notifier.state.isOffline, isTrue);

      notifier.reportNetworkSuccess();
      expect(notifier.state.status, SyncStatus.synced);
      expect(notifier.state.isOffline, isFalse);
      expect(notifier.state.errorMessage, isNull);
    });

    test('triggerSync executes registered sync callbacks and flushes queue', () async {
      bool callbackExecuted = false;
      notifier.registerSyncCallback(() async {
        callbackExecuted = true;
      });

      notifier.enqueueItem(
        title: 'Pending offline dues',
        type: 'Contribution',
      );
      expect(notifier.state.pendingCount, 1);

      await notifier.triggerSync();

      expect(callbackExecuted, isTrue);
      expect(notifier.state.pendingCount, 0);
      expect(notifier.state.status, SyncStatus.synced);
    });
  });
}
