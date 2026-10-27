import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/chat_repository.dart';
import '../../domain/models/chat_message.dart';

class ChatState extends Equatable {
  const ChatState({
    required this.idirId,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
    this.isRealtimeConnected = false,
  });

  final String idirId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;
  final bool isRealtimeConnected;

  ChatState copyWith({
    String? idirId,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? Function()? errorMessage,
    bool? isRealtimeConnected,
  }) {
    return ChatState(
      idirId: idirId ?? this.idirId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      isRealtimeConnected: isRealtimeConnected ?? this.isRealtimeConnected,
    );
  }

  @override
  List<Object?> get props => [
        idirId,
        messages,
        isLoading,
        isSending,
        errorMessage,
        isRealtimeConnected,
      ];
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier({
    required this.idirId,
    required this.chatRepository,
    required this.ref,
  }) : super(ChatState(idirId: idirId, isLoading: true)) {
    _init();
  }

  final String idirId;
  final ChatRepository chatRepository;
  final Ref ref;

  RealtimeChannel? _realtimeChannel;
  static const _uuid = Uuid();

  Future<void> _init() async {
    await loadMessages();
    _subscribeRealtime();
  }

  /// Load historical chat messages
  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final history = await chatRepository.getMessages(idirId: idirId, limit: 100);
      if (!mounted) return;
      state = state.copyWith(
        messages: history,
        isLoading: false,
        errorMessage: () => null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Subscribe to Supabase Realtime channel
  void _subscribeRealtime() {
    _realtimeChannel = chatRepository.subscribeToMessages(
      idirId: idirId,
      onMessageReceived: _handleIncomingMessage,
      onMessageEdited: _handleMessageEdited,
      onMessageDeleted: _handleMessageDeleted,
    );
    if (_realtimeChannel != null && mounted) {
      state = state.copyWith(isRealtimeConnected: true);
    }
  }

  /// Handle incoming real-time message without creating duplicates
  void _handleIncomingMessage(ChatMessage message) {
    if (!mounted) return;

    final existingIndex = state.messages.indexWhere((m) => m.id == message.id);
    if (existingIndex >= 0) {
      final updated = List<ChatMessage>.from(state.messages);
      updated[existingIndex] = message;
      state = state.copyWith(messages: updated);
      return;
    }

    final pendingIndex = state.messages.indexWhere(
      (m) =>
          (m.deliveryStatus == MessageDeliveryStatus.sending ||
              m.deliveryStatus == MessageDeliveryStatus.failed ||
              m.id.startsWith('temp-')) &&
          (m.senderId == message.senderId ||
              m.senderId.isEmpty ||
              message.senderId.isEmpty) &&
          m.content.trim() == message.content.trim(),
    );

    if (pendingIndex >= 0) {
      final updated = List<ChatMessage>.from(state.messages);
      updated[pendingIndex] = message;
      state = state.copyWith(messages: updated);
      return;
    }

    state = state.copyWith(
      messages: [...state.messages, message],
    );
  }

  /// Handle incoming edit from realtime
  void _handleMessageEdited(ChatMessage message) {
    if (!mounted) return;
    final index = state.messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      final updated = List<ChatMessage>.from(state.messages);
      updated[index] = message;
      state = state.copyWith(messages: updated);
    }
  }

  /// Handle incoming deletion from realtime
  void _handleMessageDeleted(String messageId) {
    if (!mounted) return;
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != messageId).toList(),
    );
  }

  /// Send a new message with optimistic UI and failure handling
  Future<void> sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final user = ref.read(currentUserProvider);
    final tempId = 'temp-${_uuid.v4()}';
    final now = DateTime.now();

    final optimisticMsg = ChatMessage(
      id: tempId,
      idirId: idirId,
      membershipId: user?.memberId ?? '',
      senderId: user?.uid ?? '',
      senderName: user?.name.isNotEmpty == true ? user!.name : 'Idir Member',
      senderRole: user?.role.name.toUpperCase() ?? 'MEMBER',
      content: cleanText,
      createdAt: now,
      deliveryStatus: MessageDeliveryStatus.sending,
    );

    state = state.copyWith(
      messages: [...state.messages, optimisticMsg],
      isSending: true,
    );

    try {
      final confirmed = await chatRepository.sendMessage(
        idirId: idirId,
        content: cleanText,
      );

      if (!mounted) return;

      final alreadyPresent = state.messages.any((m) => m.id == confirmed.id);
      final updated = state.messages
          .map((m) => m.id == tempId ? confirmed : m)
          .where((m) => !alreadyPresent || m.id != tempId)
          .toList();

      state = state.copyWith(
        messages: updated,
        isSending: false,
      );
    } catch (e) {
      debugPrint('[ChatNotifier] Send message error: $e');
      if (!mounted) return;

      final updated = state.messages.map((m) {
        return m.id == tempId
            ? m.copyWith(deliveryStatus: MessageDeliveryStatus.failed)
            : m;
      }).toList();

      state = state.copyWith(
        messages: updated,
        isSending: false,
      );
    }
  }

  /// Edit an existing message with optimistic update
  Future<void> editMessage(String messageId, String newContent) async {
    final cleanText = newContent.trim();
    if (cleanText.isEmpty) return;

    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;

    final originalMessage = state.messages[index];
    if (originalMessage.content == cleanText) return;

    // Optimistically update
    final optimistic = originalMessage.copyWith(
      content: cleanText,
      isEdited: true,
    );
    final updatedList = List<ChatMessage>.from(state.messages);
    updatedList[index] = optimistic;
    state = state.copyWith(messages: updatedList);

    try {
      final confirmed = await chatRepository.editMessage(
        idirId: idirId,
        messageId: messageId,
        content: cleanText,
      );

      if (!mounted) return;
      final curIdx = state.messages.indexWhere((m) => m.id == messageId);
      if (curIdx >= 0) {
        final confirmedList = List<ChatMessage>.from(state.messages);
        confirmedList[curIdx] = confirmed;
        state = state.copyWith(messages: confirmedList);
      }
    } catch (e) {
      debugPrint('[ChatNotifier] Edit message error: $e');
      if (!mounted) return;
      // Revert on error
      final curIdx = state.messages.indexWhere((m) => m.id == messageId);
      if (curIdx >= 0) {
        final revertedList = List<ChatMessage>.from(state.messages);
        revertedList[curIdx] = originalMessage;
        state = state.copyWith(
          messages: revertedList,
          errorMessage: () => 'Failed to edit message. Please try again.',
        );
      }
    }
  }

  /// Delete an existing message with optimistic update
  Future<void> deleteMessage(String messageId) async {
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;

    final originalMessage = state.messages[index];

    // Optimistically remove
    final updatedList = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: updatedList);

    try {
      await chatRepository.deleteMessage(
        idirId: idirId,
        messageId: messageId,
      );
    } catch (e) {
      debugPrint('[ChatNotifier] Delete message error: $e');
      if (!mounted) return;
      // Revert on error
      final restoredList = List<ChatMessage>.from(state.messages);
      final insertIndex = index <= restoredList.length ? index : restoredList.length;
      restoredList.insert(insertIndex, originalMessage);
      state = state.copyWith(
        messages: restoredList,
        errorMessage: () => 'Failed to delete message. Please try again.',
      );
    }
  }

  /// Retry sending a failed message
  Future<void> retryMessage(ChatMessage failedMessage) async {
    final updated = state.messages.map((m) {
      return m.id == failedMessage.id
          ? m.copyWith(deliveryStatus: MessageDeliveryStatus.sending)
          : m;
    }).toList();

    state = state.copyWith(messages: updated, isSending: true);

    try {
      final confirmed = await chatRepository.sendMessage(
        idirId: idirId,
        content: failedMessage.content,
      );

      if (!mounted) return;

      final finalMessages = state.messages.map((m) {
        return m.id == failedMessage.id ? confirmed : m;
      }).toList();

      state = state.copyWith(
        messages: finalMessages,
        isSending: false,
      );
    } catch (e) {
      if (!mounted) return;

      final finalMessages = state.messages.map((m) {
        return m.id == failedMessage.id
            ? m.copyWith(deliveryStatus: MessageDeliveryStatus.failed)
            : m;
      }).toList();

      state = state.copyWith(
        messages: finalMessages,
        isSending: false,
      );
    }
  }

  @override
  void dispose() {
    chatRepository.unsubscribe(_realtimeChannel);
    super.dispose();
  }
}

final chatNotifierProvider = StateNotifierProvider.autoDispose
    .family<ChatNotifier, ChatState, String>((ref, idirId) {
  final repo = ref.watch(chatRepositoryProvider);
  return ChatNotifier(
    idirId: idirId,
    chatRepository: repo,
    ref: ref,
  );
});
