import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:idir_app/features/chat/domain/models/chat_message.dart';
import 'package:idir_app/features/chat/data/chat_repository.dart';
import 'package:idir_app/features/chat/presentation/providers/chat_provider.dart';

class MockChatRepository implements ChatRepository {
  final List<ChatMessage> messages = [];
  void Function(ChatMessage message)? onMessageCallback;
  bool isUnsubscribed = false;

  @override
  Future<List<ChatMessage>> getMessages({
    required String idirId,
    int limit = 50,
  }) async {
    return messages.where((m) => m.idirId == idirId).toList();
  }

  @override
  Future<ChatMessage> sendMessage({
    required String idirId,
    required String content,
  }) async {
    final msg = ChatMessage(
      id: 'server-${DateTime.now().millisecondsSinceEpoch}',
      idirId: idirId,
      membershipId: 'mem-1',
      senderId: 'user-1',
      senderName: 'Test Sender',
      senderRole: 'MEMBER',
      content: content,
      createdAt: DateTime.now(),
      deliveryStatus: MessageDeliveryStatus.sent,
    );
    messages.add(msg);
    return msg;
  }

  @override
  RealtimeChannel? subscribeToMessages({
    required String idirId,
    required void Function(ChatMessage message) onMessageReceived,
  }) {
    onMessageCallback = onMessageReceived;
    return null;
  }

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {
    isUnsubscribed = true;
  }
}

void main() {
  group('ChatMessage Domain Model Tests', () {
    test('creates ChatMessage and parses fromMap correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 'msg-123',
        'idirId': 'idir-001',
        'membershipId': 'mem-001',
        'senderId': 'user-100',
        'senderName': 'Abebe Tadesse',
        'senderRole': 'CHAIRPERSON',
        'content': 'Welcome to the group chat!',
        'createdAt': now.toIso8601String(),
      };

      final message = ChatMessage.fromMap(map);

      expect(message.id, 'msg-123');
      expect(message.idirId, 'idir-001');
      expect(message.membershipId, 'mem-001');
      expect(message.senderId, 'user-100');
      expect(message.senderName, 'Abebe Tadesse');
      expect(message.senderRole, 'CHAIRPERSON');
      expect(message.content, 'Welcome to the group chat!');
      expect(message.deliveryStatus, MessageDeliveryStatus.sent);
      expect(message.isFromUser('user-100'), isTrue);
      expect(message.isFromUser('user-200'), isFalse);
    });

    test('toMap formats message correctly', () {
      final now = DateTime(2026, 10, 26, 12, 0, 0);
      final message = ChatMessage(
        id: 'msg-abc',
        idirId: 'idir-xyz',
        membershipId: 'mem-xyz',
        senderId: 'user-xyz',
        senderName: 'Chaltu Bekele',
        senderRole: 'TREASURER',
        content: 'Monthly dues update',
        createdAt: now,
      );

      final map = message.toMap();
      expect(map['id'], 'msg-abc');
      expect(map['idirId'], 'idir-xyz');
      expect(map['senderName'], 'Chaltu Bekele');
      expect(map['senderRole'], 'TREASURER');
      expect(map['content'], 'Monthly dues update');
      expect(map['createdAt'], now.toIso8601String());
    });

    test('copyWith updates deliveryStatus and content', () {
      final message = ChatMessage(
        id: 'msg-temp',
        idirId: 'idir-1',
        membershipId: 'mem-1',
        senderId: 'user-1',
        senderName: 'Lami M',
        content: 'Initial text',
        createdAt: DateTime.now(),
        deliveryStatus: MessageDeliveryStatus.sending,
      );

      final updated = message.copyWith(
        deliveryStatus: MessageDeliveryStatus.failed,
      );

      expect(updated.deliveryStatus, MessageDeliveryStatus.failed);
      expect(updated.content, 'Initial text');
    });
  });

  group('ChatNotifier Unit Tests', () {
    late MockChatRepository mockRepo;
    late ProviderContainer container;
    const testIdirId = 'idir-test-101';

    setUp(() {
      mockRepo = MockChatRepository();
      container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockRepo),
          currentUserProvider.overrideWithValue(
            AppUser(
              uid: 'user-1',
              name: 'Test Sender',
              phone: '+251911111111',
              role: UserRole.member,
              memberId: 'mem-1',
              isActive: true,
              createdAt: DateTime.now(),
              idirId: testIdirId,
            ),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('loads historical messages on initialization', () async {
      mockRepo.messages.add(
        ChatMessage(
          id: 'existing-1',
          idirId: testIdirId,
          membershipId: 'mem-0',
          senderId: 'user-0',
          senderName: 'Ancient Member',
          content: 'Hello historical world',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );

      final notifier = container.read(chatNotifierProvider(testIdirId).notifier);
      await notifier.loadMessages();

      final state = container.read(chatNotifierProvider(testIdirId));
      expect(state.isLoading, isFalse);
      expect(state.messages.length, 1);
      expect(state.messages.first.content, 'Hello historical world');
    });

    test('sendMessage sends message and replaces optimistic entry', () async {
      final notifier = container.read(chatNotifierProvider(testIdirId).notifier);
      await notifier.loadMessages();

      await notifier.sendMessage('Test message from user');

      final state = container.read(chatNotifierProvider(testIdirId));
      expect(state.messages.length, 1);
      expect(state.messages.first.content, 'Test message from user');
      expect(state.messages.first.deliveryStatus, MessageDeliveryStatus.sent);
      expect(state.messages.first.id.startsWith('server-'), isTrue);
    });

    test('incoming real-time message appends to state without duplicates', () async {
      final notifier = container.read(chatNotifierProvider(testIdirId).notifier);
      await notifier.loadMessages();

      final incoming = ChatMessage(
        id: 'realtime-msg-999',
        idirId: testIdirId,
        membershipId: 'mem-peer',
        senderId: 'user-peer',
        senderName: 'Peer Member',
        content: 'New live message!',
        createdAt: DateTime.now(),
      );

      // Trigger incoming message callback
      mockRepo.onMessageCallback?.call(incoming);

      var state = container.read(chatNotifierProvider(testIdirId));
      expect(state.messages.length, 1);
      expect(state.messages.first.id, 'realtime-msg-999');

      // Trigger duplicate message callback
      mockRepo.onMessageCallback?.call(incoming);
      state = container.read(chatNotifierProvider(testIdirId));
      expect(state.messages.length, 1); // No duplicates
    });
  });
}
