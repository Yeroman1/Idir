import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../domain/models/app_notification.dart';
import '../domain/models/notification_preferences.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> getNotifications({int limit = 50});
  Future<bool> markAsRead(String notificationId);
  Future<bool> markAllAsRead();
  Future<NotificationPreferences?> getPreferences();
  Future<bool> updatePreferences(NotificationPreferences preferences);
  Future<bool> registerDeviceToken(String token, {String platform = 'android'});
  Future<bool> unregisterDeviceToken(String token);
}

class RestNotificationsRepository implements NotificationsRepository {
  RestNotificationsRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  @override
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    try {
      final res = await _api.get('/notifications?limit=$limit');
      List<dynamic>? rawList;
      if (res is List) {
        rawList = res;
      } else if (res is Map<String, dynamic> && res['data'] is List) {
        rawList = res['data'] as List<dynamic>;
      }

      if (rawList != null) {
        return rawList
            .map((item) => AppNotification.fromMap(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[NotificationsRepository] getNotifications error: $e');
    }
    return const [];
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _api.patch('/notifications/$notificationId/read');
      return true;
    } catch (e) {
      debugPrint('[NotificationsRepository] markAsRead error: $e');
      return false;
    }
  }

  @override
  Future<bool> markAllAsRead() async {
    try {
      await _api.post('/notifications/read-all');
      return true;
    } catch (e) {
      debugPrint('[NotificationsRepository] markAllAsRead error: $e');
      return false;
    }
  }

  @override
  Future<NotificationPreferences?> getPreferences() async {
    try {
      final res = await _api.get('/notifications/preferences');
      if (res is Map<String, dynamic>) {
        final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
        return NotificationPreferences.fromMap(data);
      }
    } catch (e) {
      debugPrint('[NotificationsRepository] getPreferences error: $e');
    }
    return null;
  }

  @override
  Future<bool> updatePreferences(NotificationPreferences preferences) async {
    try {
      await _api.put('/notifications/preferences', body: preferences.toMap());
      return true;
    } catch (e) {
      debugPrint('[NotificationsRepository] updatePreferences error: $e');
      return false;
    }
  }

  @override
  Future<bool> registerDeviceToken(String token, {String platform = 'android'}) async {
    try {
      await _api.post('/notifications/device-token', body: {
        'token': token,
        'platform': platform,
      });
      return true;
    } catch (e) {
      debugPrint('[NotificationsRepository] registerDeviceToken error: $e');
      return false;
    }
  }

  @override
  Future<bool> unregisterDeviceToken(String token) async {
    try {
      await _api.delete('/notifications/device-token', queryParams: {
        'token': token,
      });
      return true;
    } catch (e) {
      debugPrint('[NotificationsRepository] unregisterDeviceToken error: $e');
      return false;
    }
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RestNotificationsRepository(apiClient: apiClient);
});
