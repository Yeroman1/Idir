import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_message_bubble.dart';
import 'group_info_screen.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key, this.idirId});

  final String? idirId;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _textController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isComposing = false;
  bool _isSearchActive = false;
  String _selectedMessageType = 'TEXT';
  int _currentPinnedIndex = 0;

  // Pending attachment preview before sending
  Map<String, dynamic>? _pendingAttachment;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _textController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // When scrolled near the top, load older messages
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 80 &&
        !_scrollController.position.outOfRange) {
      final targetIdirId = _resolveIdirId();
      if (targetIdirId != null) {
        ref.read(chatNotifierProvider(targetIdirId).notifier).loadOlderMessages();
      }
    }
  }

  String? _resolveIdirId() {
    final currentUser = ref.read(currentUserProvider);
    final activeIdirState = ref.read(activeIdirProvider);
    return widget.idirId ??
        activeIdirState.activeIdir?.idirId ??
        currentUser?.idirId;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(String idirId) {
    final text = _textController.text.trim();
    if (text.isEmpty && _pendingAttachment == null) return;

    final notifier = ref.read(chatNotifierProvider(idirId).notifier);

    if (_pendingAttachment != null) {
      notifier.sendMediaMessage(
        messageType: _pendingAttachment!['messageType'] as String? ?? 'IMAGE',
        attachmentUrl: _pendingAttachment!['url'] as String,
        attachmentType: _pendingAttachment!['mimeType'] as String,
        attachmentName: _pendingAttachment!['name'] as String,
        attachmentSize: _pendingAttachment!['size'] as int?,
        attachmentDuration: _pendingAttachment!['duration'] as int?,
        caption: text.isNotEmpty ? text : null,
      );
      setState(() => _pendingAttachment = null);
    } else {
      notifier.sendMessage(
        text,
        messageType: _selectedMessageType,
      );
    }

    _textController.clear();
    setState(() {
      _isComposing = false;
      _selectedMessageType = 'TEXT';
    });

    Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
  }

  void _showAttachmentBottomSheet(BuildContext context, String idirId) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Share Media or Document',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachOption(
                    context,
                    icon: Icons.image,
                    label: 'Photo',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _promptMediaUpload(context, idirId, 'IMAGE');
                    },
                  ),
                  _buildAttachOption(
                    context,
                    icon: Icons.videocam,
                    label: 'Video',
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _promptMediaUpload(context, idirId, 'VIDEO');
                    },
                  ),
                  _buildAttachOption(
                    context,
                    icon: Icons.picture_as_pdf,
                    label: 'Document',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _promptMediaUpload(context, idirId, 'DOCUMENT');
                    },
                  ),
                  _buildAttachOption(
                    context,
                    icon: Icons.mic,
                    label: 'Voice Note',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showVoiceRecorderDialog(context, idirId);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _promptMediaUpload(BuildContext context, String idirId, String type) {
    final titleController = TextEditingController(
      text: type == 'IMAGE'
          ? 'Community_Gathering.jpg'
          : type == 'VIDEO'
              ? 'General_Assembly_Highlights.mp4'
              : 'Idir_Bylaws_2026.pdf',
    );
    final urlController = TextEditingController(
      text: type == 'IMAGE'
          ? 'https://picsum.photos/600/400'
          : type == 'VIDEO'
              ? 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'
              : 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Attach $type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'File Name', isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'Media / Document URL', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = titleController.text.trim();
              final url = urlController.text.trim();
              if (name.isNotEmpty && url.isNotEmpty) {
                setState(() {
                  _pendingAttachment = {
                    'messageType': type,
                    'name': name,
                    'url': url,
                    'mimeType': type == 'IMAGE'
                        ? 'image/jpeg'
                        : type == 'VIDEO'
                            ? 'video/mp4'
                            : 'application/pdf',
                    'size': 1024 * 1024 * 2, // 2MB
                    'duration': type == 'VIDEO' ? 30 : null,
                  };
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Attach'),
          ),
        ],
      ),
    );
  }

  void _showVoiceRecorderDialog(BuildContext context, String idirId) {
    int seconds = 0;
    Timer? recordTimer;
    bool isRecording = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          recordTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (isRecording) {
              setDialogState(() => seconds++);
            }
          });

          final minStr = (seconds ~/ 60).toString().padLeft(2, '0');
          final secStr = (seconds % 60).toString().padLeft(2, '0');

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.mic, color: Colors.teal),
                SizedBox(width: 8),
                Text('Record Voice Note'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.teal.shade50,
                  child: const Icon(
                    Icons.mic,
                    size: 40,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$minStr:$secStr',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recording voice message...',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  recordTimer?.cancel();
                  Navigator.of(ctx).pop();
                },
                child: const Text('Discard'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () {
                  recordTimer?.cancel();
                  Navigator.of(ctx).pop();
                  final dur = seconds > 0 ? seconds : 5;
                  ref.read(chatNotifierProvider(idirId).notifier).sendMediaMessage(
                        messageType: 'VOICE',
                        attachmentUrl: 'https://actions.google.com/sounds/v1/water/rain_heavy.ogg',
                        attachmentType: 'audio/ogg',
                        attachmentName: 'Voice Note (${dur}s)',
                        attachmentDuration: dur,
                        attachmentSize: dur * 16000,
                      );
                  Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
                },
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Send Audio'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMessageTypeSelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Select Broadcast Category',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Standard Member Message'),
              selected: _selectedMessageType == 'TEXT',
              onTap: () {
                setState(() => _selectedMessageType = 'TEXT');
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: Icon(Icons.campaign, color: Colors.amber.shade800),
              title: const Text('Official Announcement'),
              subtitle: const Text('Highlighted notice from leadership'),
              selected: _selectedMessageType == 'ANNOUNCEMENT',
              onTap: () {
                setState(() => _selectedMessageType = 'ANNOUNCEMENT');
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              title: const Text('Emergency / Funeral Alert'),
              subtitle: const Text('Urgent priority broadcast to all members'),
              selected: _selectedMessageType == 'EMERGENCY',
              onTap: () {
                setState(() => _selectedMessageType = 'EMERGENCY');
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_note, color: Colors.teal),
              title: const Text('Contribution Reminder'),
              subtitle: const Text('General monthly dues notice'),
              selected: _selectedMessageType == 'CONTRIBUTION_REMINDER',
              onTap: () {
                setState(() => _selectedMessageType = 'CONTRIBUTION_REMINDER');
                Navigator.of(ctx).pop();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String idirId, ChatMessage message) {
    final editController = TextEditingController(text: message.content);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          decoration: const InputDecoration(
            hintText: 'Edit your message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != message.content) {
                ref.read(chatNotifierProvider(idirId).notifier).editMessage(message.id, newText);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String idirId, ChatMessage message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(chatNotifierProvider(idirId).notifier).deleteMessage(message.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final activeIdirState = ref.watch(activeIdirProvider);

    final targetIdirId = _resolveIdirId();
    final targetIdirName = activeIdirState.activeIdir?.idirName ??
        currentUser?.idirName ??
        l10n.associationName;

    if (targetIdirId == null || targetIdirId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.groupChatTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text(
                  'No Active Idir Selected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please select or join an Idir to access its private community group chat.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final chatState = ref.watch(chatNotifierProvider(targetIdirId));
    final chatNotifier = ref.read(chatNotifierProvider(targetIdirId).notifier);
    final effectiveRole = activeIdirState.activeIdir?.role ?? currentUser?.role ?? UserRole.member;
    final canPostAnnouncement = effectiveRole.canPostAnnouncement;

    // Auto-scroll on new incoming messages
    ref.listen<ChatState>(chatNotifierProvider(targetIdirId), (prev, next) {
      if (prev != null && next.messages.length > prev.messages.length) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _isSearchActive
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search chat messages...',
                  border: InputBorder.none,
                ),
                onChanged: (val) => chatNotifier.searchMessages(val),
              )
            : InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GroupInfoScreen(
                        idirId: targetIdirId,
                        idirName: targetIdirName,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        targetIdirName.isNotEmpty ? targetIdirName[0].toUpperCase() : 'I',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            targetIdirName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: chatState.isRealtimeConnected
                                      ? AppColors.success
                                      : AppColors.warning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                chatState.isRealtimeConnected ? 'Live Realtime' : 'Connecting...',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          if (_isSearchActive)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchController.clear();
                chatNotifier.clearSearch();
                setState(() => _isSearchActive = false);
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search messages',
              onPressed: () => setState(() => _isSearchActive = true),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Group Info',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GroupInfoScreen(
                      idirId: targetIdirId,
                      idirName: targetIdirName,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // ── Pinned Message Banner ────────────────────────────────────────
          if (chatState.pinnedMessages.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final pinnedList = chatState.pinnedMessages;
                final safeIndex = _currentPinnedIndex % pinnedList.length;
                final pinned = pinnedList[safeIndex];

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.amber.shade200, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.push_pin, size: 16, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (pinnedList.length > 1) {
                              setState(() {
                                _currentPinnedIndex = (_currentPinnedIndex + 1) % pinnedList.length;
                              });
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'PINNED MESSAGE ${pinnedList.length > 1 ? "(${safeIndex + 1}/${pinnedList.length})" : ""}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '• ${pinned.senderName}',
                                    style: TextStyle(fontSize: 10, color: Colors.amber.shade900),
                                  ),
                                ],
                              ),
                              Text(
                                pinned.content.isNotEmpty ? pinned.content : (pinned.attachmentName ?? 'Attachment'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (canPostAnnouncement)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.close, size: 16, color: Colors.amber.shade800),
                          tooltip: 'Unpin',
                          onPressed: () => chatNotifier.pinMessage(pinned.id, false),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],

          // ── Members-only Privacy Banner ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline,
                    size: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.chatMembersOnlyNotice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── Loading Older Messages Indicator ─────────────────────────────
          if (chatState.isLoadingMore)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),

          // ── Messages List / Loading / Empty / Error State ───────────────
          Expanded(
            child: Builder(
              builder: (context) {
                if (chatState.isLoading && chatState.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (chatState.errorMessage != null && chatState.messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 12),
                          Text(
                            chatState.errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => chatNotifier.loadMessages(),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(l10n.retrySend),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (chatState.messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.forum_outlined,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            chatState.isSearching ? 'No messages match search' : l10n.chatEmptyTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            chatState.isSearching ? 'Try searching for other words or names.' : l10n.chatEmptyDesc,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: chatState.messages.length,
                  itemBuilder: (context, index) {
                    final msg = chatState.messages[index];
                    final isMe = currentUser != null && msg.isFromUser(currentUser.uid);

                    // Date separator check
                    bool showDateSeparator = false;
                    if (index == 0) {
                      showDateSeparator = true;
                    } else {
                      final prevMsg = chatState.messages[index - 1];
                      final prevDate = prevMsg.createdAt.toLocal();
                      final currDate = msg.createdAt.toLocal();
                      showDateSeparator = prevDate.year != currDate.year ||
                          prevDate.month != currDate.month ||
                          prevDate.day != currDate.day;
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showDateSeparator) _buildDateSeparator(context, msg.createdAt),
                        ChatMessageBubble(
                          key: ValueKey(msg.id),
                          message: msg,
                          isMe: isMe,
                          currentUserId: currentUser?.uid ?? '',
                          canModerate: canPostAnnouncement,
                          onRetry: () => chatNotifier.retryMessage(msg),
                          onReply: () => chatNotifier.setReplyingTo(msg),
                          onEdit: isMe ? () => _showEditDialog(context, targetIdirId, msg) : null,
                          onDelete: (isMe || canPostAnnouncement)
                              ? () => _showDeleteDialog(context, targetIdirId, msg)
                              : null,
                          onPin: canPostAnnouncement
                              ? (pinned) => chatNotifier.pinMessage(msg.id, pinned)
                              : null,
                          onReact: (emoji) => chatNotifier.reactToMessage(msg.id, emoji),
                          onReport: (reason) => chatNotifier.reportMessage(msg.id, reason),
                          onTapReply: (replyId) {
                            // Find and scroll to quoted message
                            final idx = chatState.messages.indexWhere((m) => m.id == replyId);
                            if (idx >= 0 && _scrollController.hasClients) {
                              _scrollController.animateTo(
                                (idx / chatState.messages.length) *
                                    _scrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Quoted Reply Preview Bar ─────────────────────────────────────
          if (chatState.replyingToMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
              child: Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${chatState.replyingToMessage!.senderName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          chatState.replyingToMessage!.content.isNotEmpty
                              ? chatState.replyingToMessage!.content
                              : (chatState.replyingToMessage!.attachmentName ?? 'Attachment'),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => chatNotifier.clearReplyingTo(),
                  ),
                ],
              ),
            ),
          ],

          // ── Pending Attachment Preview Bar ───────────────────────────────
          if (_pendingAttachment != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
              child: Row(
                children: [
                  Icon(
                    _pendingAttachment!['messageType'] == 'IMAGE'
                        ? Icons.image
                        : _pendingAttachment!['messageType'] == 'VIDEO'
                            ? Icons.videocam
                            : Icons.picture_as_pdf,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pendingAttachment!['name'] as String,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Ready to send • Add caption below',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _pendingAttachment = null),
                  ),
                ],
              ),
            ),
          ],

          // ── Leadership Mode Indicator Strip ──────────────────────────────
          if (_selectedMessageType != 'TEXT') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: _selectedMessageType == 'EMERGENCY'
                  ? Colors.red.shade100
                  : _selectedMessageType == 'ANNOUNCEMENT'
                      ? Colors.amber.shade100
                      : Colors.teal.shade100,
              child: Row(
                children: [
                  Icon(
                    _selectedMessageType == 'EMERGENCY'
                        ? Icons.warning_amber_rounded
                        : _selectedMessageType == 'ANNOUNCEMENT'
                            ? Icons.campaign
                            : Icons.event_note,
                    size: 14,
                    color: _selectedMessageType == 'EMERGENCY'
                        ? Colors.red.shade900
                        : _selectedMessageType == 'ANNOUNCEMENT'
                            ? Colors.amber.shade900
                            : Colors.teal.shade900,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Broadcasting as ${_selectedMessageType.replaceAll('_', ' ')}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _selectedMessageType == 'EMERGENCY'
                          ? Colors.red.shade900
                          : _selectedMessageType == 'ANNOUNCEMENT'
                              ? Colors.amber.shade900
                              : Colors.teal.shade900,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _selectedMessageType = 'TEXT'),
                    child: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],

          // ── Chat Input Bar ───────────────────────────────────────────────
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Attachment button
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    tooltip: 'Share media or file',
                    onPressed: () => _showAttachmentBottomSheet(context, targetIdirId),
                  ),

                  // Leader broadcast mode toggle
                  if (canPostAnnouncement)
                    IconButton(
                      icon: Icon(
                        Icons.campaign,
                        color: _selectedMessageType != 'TEXT' ? Colors.amber.shade800 : null,
                      ),
                      tooltip: 'Official Broadcast',
                      onPressed: () => _showMessageTypeSelector(context),
                    ),

                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: _pendingAttachment != null
                            ? 'Add a caption...'
                            : l10n.typeMessageHint,
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (text) {
                        final composing = text.trim().isNotEmpty || _pendingAttachment != null;
                        if (composing != _isComposing) {
                          setState(() => _isComposing = composing);
                        }
                      },
                      onSubmitted: (_) => _sendMessage(targetIdirId),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Send button or mic button
                  IconButton.filled(
                    icon: Icon(
                      (_isComposing || _pendingAttachment != null)
                          ? Icons.send_rounded
                          : Icons.mic_none,
                      size: 20,
                    ),
                    onPressed: (_isComposing || _pendingAttachment != null)
                        ? () => _sendMessage(targetIdirId)
                        : () => _showVoiceRecorderDialog(context, targetIdirId),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final local = date.toLocal();

    String label;
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      label = 'Today';
    } else if (local.year == now.year && local.month == now.month && local.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMMM d, y').format(local);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
