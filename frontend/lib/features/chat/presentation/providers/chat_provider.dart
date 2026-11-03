import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/chat_repository.dart';
import '../../domain/models/chat_message.dart';

class ChatState extends Equatable {
  const ChatState({
    required this.idirId,
    this.messages = const [],
    this.pinnedMessages = const [],
    this.replyingToMessage,
    this.searchQuery,
    this.isSearching = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMoreOldMessages = true,
    this.isSending = false,
    this.isUploading = false,
    this.isMuted = false,
    this.errorMessage,
    this.isRealtimeConnected = false,
  });

  final String idirId;
  final List<ChatMessage> messages;
  final List<ChatMessage> pinnedMessages;
  final ChatMessage? replyingToMessage;
  final String? searchQuery;
  final bool isSearching;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMoreOldMessages;
  final bool isSending;
  final bool isUploading;
  final bool isMuted;
  final String? errorMessage;
  final bool isRealtimeConnected;

  ChatState copyWith({
    String? idirId,
    List<ChatMessage>? messages,
    List<ChatMessage>? pinnedMessages,
    ChatMessage? Function()? replyingToMessage,
    String? Function()? searchQuery,
    bool? isSearching,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreOldMessages,
    bool? isSending,
    bool? isUploading,
    bool? isMuted,
    String? Function()? errorMessage,
    bool? isRealtimeConnected,
  }) {
    return ChatState(
      idirId: idirId ?? this.idirId,
      messages: messages ?? this.messages,
      pinnedMessages: pinnedMessages ?? this.pinnedMessages,
      replyingToMessage: replyingToMessage != null
          ? replyingToMessage()
          : this.replyingToMessage,
      searchQuery: searchQuery != null ? searchQuery() : this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreOldMessages: hasMoreOldMessages ?? this.hasMoreOldMessages,
      isSending: isSending ?? this.isSending,
      isUploading: isUploading ?? this.isUploading,
      isMuted: isMuted ?? this.isMuted,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      isRealtimeConnected: isRealtimeConnected ?? this.isRealtimeConnected,
    );
  }

  @override
  List<Object?> get props => [
        idirId,
        messages,
        pinnedMessages,
        replyingToMessage,
        searchQuery,
        isSearching,
        isLoading,
        isLoadingMore,
        hasMoreOldMessages,
        isSending,
        isUploading,
        isMuted,
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
    _loadMutePreference();
    await loadMessages();
    await loadPinnedMessages();
    _subscribeRealtime();
  }

  Future<void> _loadMutePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMuted = prefs.getBool('chat_muted_$idirId') ?? false;
      if (mounted) {
        state = state.copyWith(isMuted: isMuted);
      }
    } catch (_) {}
  }

  Future<void> toggleMuteChat() async {
    final next = !state.isMuted;
    state = state.copyWith(isMuted: next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('chat_muted_$idirId', next);
    } catch (_) {}
  }

  /// Load historical chat messages
  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final history = await chatRepository.getMessages(
        idirId: idirId,
        limit: 50,
        search: state.searchQuery,
      );
      if (!mounted) return;
      final pending = state.messages
          .where((m) =>
              m.deliveryStatus == MessageDeliveryStatus.sending ||
              m.deliveryStatus == MessageDeliveryStatus.failed ||
              m.id.startsWith('temp-'))
          .toList();
      final historyIds = history.map((m) => m.id).toSet();
      final filteredPending = pending
          .where((m) =>
              !historyIds.contains(m.id) &&
              (m.clientMutationId == null || !history.any((h) => h.clientMutationId == m.clientMutationId)))
          .toList();

      state = state.copyWith(
        messages: [...history, ...filteredPending],
        isLoading: false,
        hasMoreOldMessages: history.length >= 50,
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

  /// Paginated load of older messages when scrolling up
  Future<void> loadOlderMessages() async {
    if (state.isLoadingMore || !state.hasMoreOldMessages || state.messages.isEmpty) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);
    try {
      final oldestMessage = state.messages.first;
      final older = await chatRepository.getMessages(
        idirId: idirId,
        limit: 50,
        beforeCursor: oldestMessage.createdAt.toIso8601String(),
        search: state.searchQuery,
      );

      if (!mounted) return;

      final existingIds = state.messages.map((m) => m.id).toSet();
      final filteredOlder = older.where((m) => !existingIds.contains(m.id)).toList();

      state = state.copyWith(
        messages: [...filteredOlder, ...state.messages],
        isLoadingMore: false,
        hasMoreOldMessages: older.length >= 50,
      );
    } catch (e) {
      debugPrint('[ChatNotifier] Load older messages error: $e');
      if (mounted) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  /// Load pinned messages list
  Future<void> loadPinnedMessages() async {
    try {
      final pinned = await chatRepository.getPinnedMessages(idirId: idirId);
      if (!mounted) return;
      state = state.copyWith(pinnedMessages: pinned);
    } catch (e) {
      debugPrint('[ChatNotifier] Load pinned messages error: $e');
    }
  }

  /// Search within messages
  Future<void> searchMessages(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      clearSearch();
      return;
    }

    state = state.copyWith(
      searchQuery: () => clean,
      isSearching: true,
      isLoading: true,
    );

    try {
      final results = await chatRepository.getMessages(
        idirId: idirId,
        search: clean,
        limit: 100,
      );
      if (!mounted) return;
      state = state.copyWith(
        messages: results,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clearSearch() {
    state = state.copyWith(
      searchQuery: () => null,
      isSearching: false,
    );
    loadMessages();
  }

  void setReplyingTo(ChatMessage? message) {
    state = state.copyWith(replyingToMessage: () => message);
  }

  void clearReplyingTo() {
    state = state.copyWith(replyingToMessage: () => null);
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
          ((m.clientMutationId != null && m.clientMutationId == message.clientMutationId) ||
              ((m.senderId == message.senderId ||
                      m.senderId.isEmpty ||
                      message.senderId.isEmpty) &&
                  m.content.trim() == message.content.trim())),
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

    if (message.isPinned) {
      loadPinnedMessages();
    }
  }

  /// Handle incoming edit or reaction or pin update from realtime
  void _handleMessageEdited(ChatMessage message) {
    if (!mounted) return;
    final index = state.messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      final updated = List<ChatMessage>.from(state.messages);
      updated[index] = message;
      state = state.copyWith(messages: updated);
    }

    // Update in pinned messages if applicable
    if (message.isPinned) {
      final pIndex = state.pinnedMessages.indexWhere((m) => m.id == message.id);
      if (pIndex >= 0) {
        final updatedP = List<ChatMessage>.from(state.pinnedMessages);
        updatedP[pIndex] = message;
        state = state.copyWith(pinnedMessages: updatedP);
      } else {
        state = state.copyWith(pinnedMessages: [...state.pinnedMessages, message]);
      }
    } else {
      state = state.copyWith(
        pinnedMessages: state.pinnedMessages.where((m) => m.id != message.id).toList(),
      );
    }
  }

  /// Handle incoming deletion from realtime
  void _handleMessageDeleted(String messageId) {
    if (!mounted) return;
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != messageId).toList(),
      pinnedMessages: state.pinnedMessages.where((m) => m.id != messageId).toList(),
    );
  }

  /// Send a text message with reply/mention/announcement support
  Future<void> sendMessage(
    String text, {
    String messageType = 'TEXT',
    List<String>? mentions,
    bool isForwarded = false,
    String? forwardedFromName,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final user = ref.read(currentUserProvider);
    final activeIdir = ref.read(activeIdirProvider).activeIdir;
    final effectiveRole = activeIdir?.role ?? user?.role ?? UserRole.member;
    final tempId = 'temp-${_uuid.v4()}';
    final mutationId = 'mut-${_uuid.v4()}';
    final now = DateTime.now();

    final replyingTo = state.replyingToMessage;
    clearReplyingTo();

    final optimisticMsg = ChatMessage(
      id: tempId,
      idirId: idirId,
      membershipId: activeIdir?.id ?? user?.memberId ?? '',
      senderId: user?.uid ?? '',
      senderName: user?.name.isNotEmpty == true ? user!.name : 'Idir Member',
      senderRole: effectiveRole.name.toUpperCase(),
      content: cleanText,
      messageType: messageType,
      replyToId: replyingTo?.id,
      replyToSenderName: replyingTo?.senderName,
      replyToContent: replyingTo?.content,
      isForwarded: isForwarded,
      forwardedFromName: forwardedFromName,
      mentions: mentions ?? const [],
      clientMutationId: mutationId,
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
        messageType: messageType,
        replyToId: replyingTo?.id,
        isForwarded: isForwarded,
        forwardedFromName: forwardedFromName,
        mentions: mentions,
        clientMutationId: mutationId,
      );

      if (!mounted) return;

      final alreadyPresent = state.messages.any((m) => m.id == confirmed.id);
      final hasTemp = state.messages.any((m) => m.id == tempId || m.clientMutationId == mutationId);
      List<ChatMessage> updated;
      if (hasTemp) {
        updated = state.messages
            .map((m) => (m.id == tempId || m.clientMutationId == mutationId) ? confirmed : m)
            .toList();
      } else if (!alreadyPresent) {
        updated = [...state.messages, confirmed];
      } else {
        updated = state.messages;
      }

      state = state.copyWith(
        messages: updated,
        isSending: false,
      );
    } catch (e) {
      debugPrint('[ChatNotifier] Send message error: $e');
      if (!mounted) return;

      final updated = state.messages.map((m) {
        return (m.id == tempId || m.clientMutationId == mutationId)
            ? m.copyWith(deliveryStatus: MessageDeliveryStatus.failed)
            : m;
      }).toList();

      state = state.copyWith(
        messages: updated,
        isSending: false,
      );
    }
  }

  /// Send media / document / audio / voice message
  Future<void> sendMediaMessage({
    required String messageType,
    required String attachmentUrl,
    required String attachmentType,
    required String attachmentName,
    int? attachmentSize,
    int? attachmentDuration,
    String? caption,
  }) async {
    final user = ref.read(currentUserProvider);
    final activeIdir = ref.read(activeIdirProvider).activeIdir;
    final effectiveRole = activeIdir?.role ?? user?.role ?? UserRole.member;
    final tempId = 'temp-${_uuid.v4()}';
    final mutationId = 'mut-${_uuid.v4()}';
    final now = DateTime.now();

    final replyingTo = state.replyingToMessage;
    clearReplyingTo();

    final cleanCaption = caption?.trim() ?? '';

    final optimisticMsg = ChatMessage(
      id: tempId,
      idirId: idirId,
      membershipId: activeIdir?.id ?? user?.memberId ?? '',
      senderId: user?.uid ?? '',
      senderName: user?.name.isNotEmpty == true ? user!.name : 'Idir Member',
      senderRole: effectiveRole.name.toUpperCase(),
      content: cleanCaption,
      messageType: messageType,
      replyToId: replyingTo?.id,
      replyToSenderName: replyingTo?.senderName,
      replyToContent: replyingTo?.content,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      attachmentName: attachmentName,
      attachmentSize: attachmentSize,
      attachmentDuration: attachmentDuration,
      clientMutationId: mutationId,
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
        content: cleanCaption,
        messageType: messageType,
        replyToId: replyingTo?.id,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        attachmentName: attachmentName,
        attachmentSize: attachmentSize,
        attachmentDuration: attachmentDuration,
        clientMutationId: mutationId,
      );

      if (!mounted) return;

      final alreadyPresent = state.messages.any((m) => m.id == confirmed.id);
      final hasTemp = state.messages.any((m) => m.id == tempId || m.clientMutationId == mutationId);
      List<ChatMessage> updated;
      if (hasTemp) {
        updated = state.messages
            .map((m) => (m.id == tempId || m.clientMutationId == mutationId) ? confirmed : m)
            .toList();
      } else if (!alreadyPresent) {
        updated = [...state.messages, confirmed];
      } else {
        updated = state.messages;
      }

      state = state.copyWith(
        messages: updated,
        isSending: false,
      );
    } catch (e) {
      debugPrint('[ChatNotifier] Send media message error: $e');
      if (!mounted) return;

      final updated = state.messages.map((m) {
        return (m.id == tempId || m.clientMutationId == mutationId)
            ? m.copyWith(deliveryStatus: MessageDeliveryStatus.failed)
            : m;
      }).toList();

      state = state.copyWith(
        messages: updated,
        isSending: false,
      );
    }
  }

  /// Upload file to backend storage endpoint
  Future<Map<String, dynamic>> uploadAttachmentFile({
    required String fileName,
    required String mimeType,
    required int size,
    String? base64Data,
  }) async {
    state = state.copyWith(isUploading: true);
    try {
      final res = await chatRepository.uploadAttachment(
        idirId: idirId,
        fileName: fileName,
        mimeType: mimeType,
        size: size,
        base64Data: base64Data,
      );
      if (mounted) state = state.copyWith(isUploading: false);
      return res;
    } catch (e) {
      if (mounted) state = state.copyWith(isUploading: false);
      rethrow;
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

    final updatedList = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(
      messages: updatedList,
      pinnedMessages: state.pinnedMessages.where((m) => m.id != messageId).toList(),
    );

    try {
      await chatRepository.deleteMessage(
        idirId: idirId,
        messageId: messageId,
      );
    } catch (e) {
      debugPrint('[ChatNotifier] Delete message error: $e');
      if (!mounted) return;
      final restoredList = List<ChatMessage>.from(state.messages);
      final insertIndex = index <= restoredList.length ? index : restoredList.length;
      restoredList.insert(insertIndex, originalMessage);
      state = state.copyWith(
        messages: restoredList,
        errorMessage: () => 'Failed to delete message. Please try again.',
      );
    }
  }

  /// Pin or unpin message with optimistic update
  Future<void> pinMessage(String messageId, bool isPinned) async {
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;

    final original = state.messages[index];
    final optimistic = original.copyWith(
      isPinned: isPinned,
      pinnedAt: isPinned ? DateTime.now() : null,
    );

    final updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages[index] = optimistic;

    List<ChatMessage> updatedPinned = List.from(state.pinnedMessages);
    if (isPinned) {
      if (!updatedPinned.any((m) => m.id == messageId)) {
        updatedPinned.insert(0, optimistic);
      }
    } else {
      updatedPinned.removeWhere((m) => m.id == messageId);
    }

    state = state.copyWith(
      messages: updatedMessages,
      pinnedMessages: updatedPinned,
    );

    try {
      final confirmed = await chatRepository.pinMessage(
        idirId: idirId,
        messageId: messageId,
        isPinned: isPinned,
      );
      if (!mounted) return;
      _handleMessageEdited(confirmed);
    } catch (e) {
      debugPrint('[ChatNotifier] Pin message error: $e');
      if (!mounted) return;
      // Revert
      final revMessages = List<ChatMessage>.from(state.messages);
      final rIndex = revMessages.indexWhere((m) => m.id == messageId);
      if (rIndex >= 0) revMessages[rIndex] = original;
      state = state.copyWith(
        messages: revMessages,
        errorMessage: () => 'Failed to update pinned state. Admin rights may be required.',
      );
      loadPinnedMessages();
    }
  }

  /// React to a message with emoji (toggles emoji)
  Future<void> reactToMessage(String messageId, String emoji) async {
    final user = ref.read(currentUserProvider);
    final userId = user?.uid ?? 'me';
    final userName = user?.name ?? 'Member';

    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;

    final original = state.messages[index];
    final alreadyReacted = original.hasUserReacted(userId, emoji);
    final action = alreadyReacted ? 'remove' : 'add';

    List<MessageReaction> newReactions = List.from(original.reactions);
    if (alreadyReacted) {
      newReactions.removeWhere((r) => r.userId == userId && r.emoji == emoji);
    } else {
      newReactions.add(MessageReaction(emoji: emoji, userId: userId, userName: userName));
    }

    final optimistic = original.copyWith(reactions: newReactions);
    final updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages[index] = optimistic;
    state = state.copyWith(messages: updatedMessages);

    try {
      final confirmed = await chatRepository.reactToMessage(
        idirId: idirId,
        messageId: messageId,
        emoji: emoji,
        action: action,
      );
      if (!mounted) return;
      _handleMessageEdited(confirmed);
    } catch (e) {
      debugPrint('[ChatNotifier] React message error: $e');
      if (!mounted) return;
      final revMessages = List<ChatMessage>.from(state.messages);
      final rIndex = revMessages.indexWhere((m) => m.id == messageId);
      if (rIndex >= 0) revMessages[rIndex] = original;
      state = state.copyWith(messages: revMessages);
    }
  }

  /// Report inappropriate message
  Future<void> reportMessage(String messageId, String reason, {String? details}) async {
    await chatRepository.reportMessage(
      idirId: idirId,
      messageId: messageId,
      reason: reason,
      details: details,
    );
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
        messageType: failedMessage.messageType,
        replyToId: failedMessage.replyToId,
        attachmentUrl: failedMessage.attachmentUrl,
        attachmentType: failedMessage.attachmentType,
        attachmentName: failedMessage.attachmentName,
        attachmentSize: failedMessage.attachmentSize,
        attachmentDuration: failedMessage.attachmentDuration,
        mentions: failedMessage.mentions,
        clientMutationId: failedMessage.clientMutationId,
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
