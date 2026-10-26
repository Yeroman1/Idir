import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/api_client.dart';
import '../domain/models/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatMessage>> getMessages({
    required String idirId,
    int limit = 50,
  });

  Future<ChatMessage> sendMessage({
    required String idirId,
    required String content,
  });

  RealtimeChannel? subscribeToMessages({
    required String idirId,
    required void Function(ChatMessage message) onMessageReceived,
  });

  Future<void> unsubscribe(RealtimeChannel? channel);
}

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  SupabaseClient? _getSupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ChatMessage>> getMessages({
    required String idirId,
    int limit = 50,
  }) async {
    // 1. Primary path: Use Idir Connect authenticated API endpoint
    try {
      final res = await _apiClient.get(
        '/idirs/$idirId/chat?limit=$limit',
      );

      List<dynamic>? rawList;
      if (res is List) {
        rawList = res;
      } else if (res is Map<String, dynamic> && res['data'] is List) {
        rawList = res['data'] as List<dynamic>;
      }

      if (rawList != null) {
        return rawList
            .map((item) => ChatMessage.fromMap(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[ChatRepository] Backend REST getMessages notice: $e');
      // If backend call failed, fallback to Supabase direct query if client is available
      final supabase = _getSupabaseClient();
      if (supabase != null) {
        final records = await supabase
            .from('ChatMessage')
            .select()
            .eq('idirId', idirId)
            .order('createdAt', ascending: true)
            .limit(limit);

        return (records as List<dynamic>)
            .map((m) => ChatMessage.fromMap(m as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }

    return const [];
  }

  @override
  Future<ChatMessage> sendMessage({
    required String idirId,
    required String content,
  }) async {
    // 1. Primary path: Use Idir Connect backend API (validates active membership & persists to Supabase PostgreSQL)
    try {
      final res = await _apiClient.post(
        '/idirs/$idirId/chat',
        body: {'content': content.trim()},
      );

      Map<String, dynamic>? messageMap;
      if (res is Map<String, dynamic>) {
        if (res['data'] is Map<String, dynamic>) {
          messageMap = res['data'] as Map<String, dynamic>;
        } else if (res.containsKey('content') || res.containsKey('id')) {
          messageMap = res;
        }
      }

      if (messageMap != null) {
        final created = ChatMessage.fromMap(messageMap);

        // Broadcast to channel for instant delivery
        final supabase = _getSupabaseClient();
        if (supabase != null) {
          try {
            final channel = supabase.channel('idir-chat-$idirId');
            channel.sendBroadcastMessage(
              event: 'chat_message',
              payload: created.toMap(),
            );
          } catch (_) {}
        }

        return created;
      }
      throw Exception('Failed to send message: invalid server response');
    } catch (e) {
      debugPrint('[ChatRepository] Backend REST sendMessage notice: $e');
      // Fallback: direct Supabase insert if direct client exists
      final supabase = _getSupabaseClient();
      if (supabase != null) {
        final user = supabase.auth.currentUser;
        final inserted = await supabase
            .from('ChatMessage')
            .insert({
              'id': uuidV4(),
              'idirId': idirId,
              'senderId': user?.id ?? 'web-user',
              'senderName': user?.userMetadata?['fullName'] ?? 'Idir Member',
              'content': content.trim(),
            })
            .select()
            .single();

        return ChatMessage.fromMap(inserted);
      }
      rethrow;
    }
  }

  @override
  RealtimeChannel? subscribeToMessages({
    required String idirId,
    required void Function(ChatMessage message) onMessageReceived,
  }) {
    final supabase = _getSupabaseClient();
    if (supabase == null) {
      debugPrint('[ChatRepository] Supabase client unavailable for realtime channel.');
      return null;
    }

    try {
      final channelName = 'idir-chat-$idirId';
      final channel = supabase.channel(channelName);

      // 1. Listen for PostgreSQL logical replication INSERT events on ChatMessage table
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'ChatMessage',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'idirId',
          value: idirId,
        ),
        callback: (payload) {
          try {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              final msg = ChatMessage.fromMap(newRecord);
              onMessageReceived(msg);
            }
          } catch (e) {
            debugPrint('[ChatRepository] Postgres change parse error: $e');
          }
        },
      );

      // 2. Also listen for Realtime broadcast events for instantaneous cross-client messaging
      channel.onBroadcast(
        event: 'chat_message',
        callback: (payload) {
          try {
            final msg = ChatMessage.fromMap(payload);
            onMessageReceived(msg);
          } catch (e) {
            debugPrint('[ChatRepository] Broadcast message parse error: $e');
          }
        },
      );

      channel.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('[ChatRepository] Subscribed to realtime channel: $channelName');
        } else if (status == RealtimeSubscribeStatus.timedOut) {
          debugPrint('[ChatRepository] Subscription timed out on: $channelName');
        } else if (error != null) {
          debugPrint('[ChatRepository] Subscription error on $channelName: $error');
        }
      });

      return channel;
    } catch (e) {
      debugPrint('[ChatRepository] Error establishing Realtime subscription: $e');
      return null;
    }
  }

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {
    if (channel == null) return;
    try {
      final supabase = _getSupabaseClient();
      if (supabase != null) {
        await supabase.removeChannel(channel);
        debugPrint('[ChatRepository] Successfully unsubscribed from chat channel.');
      }
    } catch (e) {
      debugPrint('[ChatRepository] Error during channel unsubscribe: $e');
    }
  }

  static String uuidV4() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SupabaseChatRepository(apiClient: apiClient);
});
