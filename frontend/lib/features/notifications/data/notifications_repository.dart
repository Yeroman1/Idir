import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../domain/models/app_notification.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> getNotifications({int limit = 50});
  Future<bool> markAsRead(String notificationId);
  Future<bool> markAllAsRead();
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
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RestNotificationsRepository(apiClient: apiClient);
});

