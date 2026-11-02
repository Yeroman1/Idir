import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:idir_app/features/chat/domain/models/chat_message.dart';
import 'package:idir_app/features/chat/data/chat_repository.dart';
import 'package:idir_app/features/chat/presentation/providers/chat_provider.dart';

class MockChatRepository implements ChatRepository {
  final List<ChatMessage> messages = [];
  final List<ChatMessage> pinned = [];
  final List<Map<String, dynamic>> reported = [];

  void Function(ChatMessage message)? onMessageCallback;
  void Function(ChatMessage message)? onEditedCallback;
  void Function(String messageId)? onDeletedCallback;
  bool isUnsubscribed = false;

  @override
  Future<List<ChatMessage>> getMessages({
    required String idirId,
    int limit = 50,
    String? beforeCursor,
    String? search,
    bool? pinnedOnly,
  }) async {
    var filtered = messages.where((m) => m.idirId == idirId).toList();
    if (pinnedOnly == true) {
      filtered = filtered.where((m) => m.isPinned).toList();
    }
    if (beforeCursor != null && beforeCursor.isNotEmpty) {
      final cursorDate = DateTime.tryParse(beforeCursor);
      if (cursorDate != null) {
        filtered = filtered.where((m) => m.createdAt.isBefore(cursorDate)).toList();
      }
    }
    if (search != null && search.isNotEmpty) {
      final query = search.toLowerCase();
      filtered = filtered.where((m) => m.content.toLowerCase().contains(query)).toList();
    }
    return filtered.take(limit).toList();
  }

  @override
  Future<List<ChatMessage>> getPinnedMessages({required String idirId}) async {
    return messages.where((m) => m.idirId == idirId && m.isPinned).toList();
  }

  @override
  Future<ChatMessage> sendMessage({
    required String idirId,
    required String content,
    String messageType = 'TEXT',
    String? replyToId,
    bool isForwarded = false,
    String? forwardedFromName,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentName,
    int? attachmentSize,
    int? attachmentDuration,
    List<String>? mentions,
    String? clientMutationId,
  }) async {
    ChatMessage? replyMsg;
    if (replyToId != null) {
      replyMsg = messages.firstWhere((m) => m.id == replyToId, orElse: () => messages.first);
    }

    final msg = ChatMessage(
      id: 'server-${DateTime.now().microsecondsSinceEpoch}',
      idirId: idirId,
      membershipId: 'mem-1',
      senderId: 'user-1',
      senderName: 'Test Sender',
      senderRole: 'MEMBER',
      content: content,
      messageType: messageType,
      replyToId: replyToId,
      replyToSenderName: replyMsg?.senderName,
      replyToContent: replyMsg?.content,
      isForwarded: isForwarded,
      forwardedFromName: forwardedFromName,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      attachmentName: attachmentName,
      attachmentSize: attachmentSize,
      attachmentDuration: attachmentDuration,
      mentions: mentions ?? const [],
      clientMutationId: clientMutationId,
      createdAt: DateTime.now(),
      deliveryStatus: MessageDeliveryStatus.sent,
    );
    messages.add(msg);
    return msg;
  }

  @override
  Future<ChatMessage> editMessage({
    required String idirId,
    required String messageId,
    required String content,
  }) async {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      final updated = messages[index].copyWith(content: content, isEdited: true);
      messages[index] = updated;
      return updated;
    }
    throw Exception('Message not found');
  }

  @override
  Future<void> deleteMessage({
    required String idirId,
    required String messageId,
  }) async {
    messages.removeWhere((m) => m.id == messageId);
  }

  @override
  Future<ChatMessage> pinMessage({
    required String idirId,
    required String messageId,
    required bool isPinned,
  }) async {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      final updated = messages[index].copyWith(
        isPinned: isPinned,
        pinnedAt: isPinned ? DateTime.now() : null,
      );
      messages[index] = updated;
      return updated;
    }
    throw Exception('Message not found');
  }

  @override
  Future<ChatMessage> reactToMessage({
    required String idirId,
    required String messageId,
    required String emoji,
    String action = 'add',
  }) async {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      final current = messages[index];
      List<MessageReaction> newReactions = List.from(current.reactions);
      if (action == 'remove') {
        newReactions.removeWhere((r) => r.emoji == emoji);
      } else {
        newReactions.add(MessageReaction(emoji: emoji, userId: 'user-1', userName: 'Test Sender'));
      }
      final updated = current.copyWith(reactions: newReactions);
      messages[index] = updated;
      return updated;
    }
    throw Exception('Message not found');
  }

  @override
  Future<void> reportMessage({
    required String idirId,
    required String messageId,
    required String reason,
    String? details,
  }) async {
    reported.add({
      'idirId': idirId,
      'messageId': messageId,
      'reason': reason,
      'details': details,
    });
  }

  @override
  Future<Map<String, dynamic>> uploadAttachment({
    required String idirId,
    required String fileName,
    required String mimeType,
    required int size,
    String? base64Data,
  }) async {
    return {
      'url': 'https://mock-storage.local/$fileName',
      'fileName': fileName,
      'mimeType': mimeType,
      'size': size,
    };
  }

  @override
  RealtimeChannel? subscribeToMessages({
    required String idirId,
    required void Function(ChatMessage message) onMessageReceived,
    void Function(ChatMessage message)? onMessageEdited,
    void Function(String messageId)? onMessageDeleted,
  }) {
    onMessageCallback = onMessageReceived;
    onEditedCallback = onMessageEdited;
    onDeletedCallback = onMessageDeleted;
    return null;
  }

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {
    isUnsubscribed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatMessage Domain Model Tests', () {
    test('creates ChatMessage and parses fromMap correctly with new fields', () {
      final now = DateTime.now();
      final map = {
        'id': 'msg-123',
        'idirId': 'idir-001',
        'membershipId': 'mem-001',
        'senderId': 'user-100',
        'senderName': 'Abebe Tadesse',
        'senderRole': 'CHAIRPERSON',
        'content': 'Official assembly notice',
        'messageType': 'ANNOUNCEMENT',
        'isPinned': true,
        'pinnedAt': now.toIso8601String(),
        'replyToId': 'msg-000',
        'replyToSenderName': 'Almaz',
        'replyToContent': 'When is the meeting?',
        'isForwarded': true,
        'forwardedFromName': 'Elder Council',
        'attachmentUrl': 'https://example.com/agenda.pdf',
        'attachmentType': 'application/pdf',
        'attachmentName': 'Agenda.pdf',
        'attachmentSize': 2048,
        'reactions': [
          {'emoji': '👍', 'userId': 'user-1', 'userName': 'Abebe'},
          {'emoji': '❤️', 'userId': 'user-2', 'userName': 'Chaltu'},
        ],
        'mentions': ['@all'],
        'createdAt': now.toIso8601String(),
      };

      final message = ChatMessage.fromMap(map);

      expect(message.id, 'msg-123');
      expect(message.idirId, 'idir-001');
      expect(message.membershipId, 'mem-001');
      expect(message.senderId, 'user-100');
      expect(message.senderName, 'Abebe Tadesse');
      expect(message.senderRole, 'CHAIRPERSON');
      expect(message.content, 'Official assembly notice');
      expect(message.messageType, 'ANNOUNCEMENT');
      expect(message.isAnnouncement, isTrue);
      expect(message.isSpecialAlert, isTrue);
      expect(message.isPinned, isTrue);
      expect(message.hasReply, isTrue);
      expect(message.replyToSenderName, 'Almaz');
      expect(message.isForwarded, isTrue);
      expect(message.forwardedFromName, 'Elder Council');
      expect(message.hasAttachment, isTrue);
      expect(message.isPdfOrDoc, isTrue);
      expect(message.reactions.length, 2);
      expect(message.hasUserReacted('user-1', '👍'), isTrue);
      expect(message.hasUserReacted('user-1', '❤️'), isFalse);
      expect(message.deliveryStatus, MessageDeliveryStatus.sent);
      expect(message.isFromUser('user-100'), isTrue);
      expect(message.isFromUser('user-200'), isFalse);
    });

    test('toMap formats message and reactions correctly', () {
      final now = DateTime(2026, 10, 26, 12, 0, 0);
      final message = ChatMessage(
        id: 'msg-abc',
        idirId: 'idir-xyz',
        membershipId: 'mem-xyz',
        senderId: 'user-xyz',
        senderName: 'Chaltu Bekele',
        senderRole: 'TREASURER',
        content: 'Monthly dues update',
        messageType: 'CONTRIBUTION_REMINDER',
        isPinned: true,
        reactions: const [
          MessageReaction(emoji: '🙏', userId: 'user-xyz', userName: 'Chaltu Bekele'),
        ],
        createdAt: now,
      );

      final map = message.toMap();
      expect(map['id'], 'msg-abc');
      expect(map['idirId'], 'idir-xyz');
      expect(map['senderName'], 'Chaltu Bekele');
      expect(map['senderRole'], 'TREASURER');
      expect(map['content'], 'Monthly dues update');
      expect(map['messageType'], 'CONTRIBUTION_REMINDER');
      expect(map['isPinned'], isTrue);
      expect(map['reactions'], isA<List>());
      expect(((map['reactions'] as List).first as Map<String, dynamic>)['emoji'], '🙏');
      expect(map['createdAt'], now.toIso8601String());
    });

    test('groupedReactions aggregates emojis correctly', () {
      final msg = ChatMessage(
        id: '1',
        idirId: 'idir-1',
        membershipId: 'mem-1',
        senderId: 'u1',
        senderName: 'User 1',
        content: 'Hi',
        reactions: const [
          MessageReaction(emoji: '👍', userId: 'u1', userName: 'User 1'),
          MessageReaction(emoji: '👍', userId: 'u2', userName: 'User 2'),
          MessageReaction(emoji: '❤️', userId: 'u3', userName: 'User 3'),
        ],
        createdAt: DateTime.now(),
      );

      final grouped = msg.groupedReactions;
      expect(grouped['👍']?.length, 2);
      expect(grouped['❤️']?.length, 1);
      expect(grouped['😂'], isNull);
    });
  });

  group('ChatNotifier Unit Tests', () {
    late MockChatRepository mockRepo;
    late ProviderContainer container;
    const testIdirId = 'idir-test-101';

    setUp(() {
      SharedPreferences.setMockInitialValues({'chat_muted_$testIdirId': false});
      mockRepo = MockChatRepository();
      container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockRepo),
          currentUserProvider.overrideWithValue(
            AppUser(
              uid: 'user-1',
              name: 'Test Sender',
              phone: '+251911111111',
              role: UserRole.chairperson,
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

    test('loads historical messages and mute preference on initialization', () async {
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
      expect(state.isMuted, isFalse);
    });

    test('sendMessage with reply links correctly', () async {
      final notifier = container.read(chatNotifierProvider(testIdirId).notifier);
      await notifier.loadMessages();

      // First send a message to reply to
      await notifier.sendMessage('Initial question');
      final original = container.read(chatNotifierProvider(testIdirId)).messages.first;

      // Set replying to
      notifier.setReplyingTo(original);
      expect(container.read(chatNotifierProvider(testIdirId)).replyingToMessage?.id, original.id);

      // Send reply
      await notifier.sendMessage('This is the answer');

      final state = container.read(chatNotifierProvider(testIdirId));
      expect(state.messages.length, 2);
      final reply = state.messages.last;
      expect(reply.content, 'This is the answer');
      expect(reply.replyToId, original.id);
      expect(state.replyingToMessage, isNull); // Cleared after sending
    });

    test('pinMessage pins message and updates pinnedMessages list', () async {
      final notifier = container.read(chatNotifierProvider(testIdirId).notifier);
      await notifier.loadMessages();
      await notifier.sendMessage('Important guideline');

      final msg = container.read(chatNotifierProvider(testIdirId)).messages.first;
      await notifier.pinMessage(msg.id, true);

      final state = container.read(chatNotifierProvider(testIdirId));
      expect(state.messages.first.isPinned, isTrue);
      expect(state.pinnedMessages.length, 1);
      expect(state.pinnedMessages.first.id, msg.id);

      // Unpin
      await notifier.pinMessage(msg.id, false);
      final stateAfterUnpin = container.read(chatNotifierProvider(testIdirId));
      expect(stateAfterUnpin.messages.first.isPinned, isFalse);
      expect(stateAfterUnpin.pinnedMessages.isEmpty, isTrue);
    });

    test('reactToMessage toggles emoji reactions', () async {
      final notifier = container.read(chatNotifierProvider(testIdirId).notifier);
      await notifier.loadMessages();
      await notifier.sendMessage('Please react to this');

      final msg = container.read(chatNotifierProvider(testIdirId)).messages.first;
      await notifier.reactToMessage(msg.id, '👍');

      var state = container.read(chatNotifierProvider(testIdirId));
      expect(state.messages.first.hasUserReacted('user-1', '👍'), isTrue);

      // Toggle off
      await notifier.reactToMessage(msg.id, '👍');
      state = container.read(chatNotifierProvider(testIdirId));
      expect(state.messages.first.hasUserReacted('user-1', '👍'), isFalse);
    });

    test('sendMediaMessage sends voice note / media attachment', () async {
      final notifier = container.read(chatNotifierProvider(testIdirId).notifier);
      await notifier.loadMessages();

      await notifier.sendMediaMessage(
        messageType: 'VOICE',
        attachmentUrl: 'https://example.com/audio.ogg',
        attachmentType: 'audio/ogg',
        attachmentName: 'Voice Note (12s)',
        attachmentDuration: 12,
        attachmentSize: 192000,
        caption: 'Listen to announcement',
      );

      final state = container.read(chatNotifierProvider(testIdirId));
      expect(state.messages.length, 1);
      final sent = state.messages.first;
      expect(sent.isAudioOrVoice, isTrue);
      expect(sent.attachmentDuration, 12);
      expect(sent.content, 'Listen to announcement');
    });

    test('searchMessages filters message list', () async {
      final notifier = container.read(chatNotifierProvider(testIdirId).notifier);
      await notifier.sendMessage('Funeral contribution schedule');
      await notifier.sendMessage('Sunday meeting reminder');

      await notifier.searchMessages('Funeral');
      final state = container.read(chatNotifierProvider(testIdirId));
      expect(state.isSearching, isTrue);
      expect(state.messages.length, 1);
      expect(state.messages.first.content.contains('Funeral'), isTrue);

      notifier.clearSearch();
      final resetState = container.read(chatNotifierProvider(testIdirId));
      expect(resetState.isSearching, isFalse);
    });

    test('reportMessage registers moderation report', () async {
      final notifier = container.read(chatNotifierProvider(testIdirId).notifier);
      await notifier.sendMessage('Spam content');
      final msg = container.read(chatNotifierProvider(testIdirId)).messages.first;

      await notifier.reportMessage(msg.id, 'Inappropriate content', details: 'Contains spam');
      expect(mockRepo.reported.length, 1);
      expect(mockRepo.reported.first['reason'], 'Inappropriate content');
    });

    test('toggleMuteChat updates state', () async {
      final notifier = container.read(chatNotifierProvider(testIdirId).notifier);
      expect(container.read(chatNotifierProvider(testIdirId)).isMuted, isFalse);

      await notifier.toggleMuteChat();
      expect(container.read(chatNotifierProvider(testIdirId)).isMuted, isTrue);

      await notifier.toggleMuteChat();
      expect(container.read(chatNotifierProvider(testIdirId)).isMuted, isFalse);
    });
  });
}
