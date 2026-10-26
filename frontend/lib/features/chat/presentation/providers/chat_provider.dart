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
      // Update existing message
      final updated = List<ChatMessage>.from(state.messages);
      updated[existingIndex] = message;
      state = state.copyWith(messages: updated);
      return;
    }

    // Check if this incoming message matches a pending optimistic message by content
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

    // Append new message to the list
    state = state.copyWith(
      messages: [...state.messages, message],
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

    // Optimistically show message immediately
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

      // Replace optimistic message with confirmed server message (if not already replaced by realtime)
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

      // Mark message as failed so user can tap to retry
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

  /// Retry sending a failed message
  Future<void> retryMessage(ChatMessage failedMessage) async {
    // Set status back to sending
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
