import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/chat_message.dart';

class ChatMessageBubble extends StatefulWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
    required this.onRetry,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onPin,
    this.onReact,
    this.onReport,
    this.onTapReply,
    this.canModerate = false,
  });

  final ChatMessage message;
  final bool isMe;
  final String currentUserId;
  final VoidCallback onRetry;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final void Function(bool isPinned)? onPin;
  final void Function(String emoji)? onReact;
  final void Function(String reason)? onReport;
  final void Function(String replyToId)? onTapReply;
  final bool canModerate;

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  bool _isPlayingAudio = false;
  double _audioProgress = 0.0;
  Timer? _audioTimer;

  @override
  void dispose() {
    _audioTimer?.cancel();
    super.dispose();
  }

  void _toggleAudioPlayback() {
    if (_isPlayingAudio) {
      _audioTimer?.cancel();
      setState(() => _isPlayingAudio = false);
    } else {
      setState(() {
        _isPlayingAudio = true;
        if (_audioProgress >= 1.0) _audioProgress = 0.0;
      });
      final totalSeconds = widget.message.attachmentDuration ?? 15;
      final step = 0.05 / totalSeconds;
      _audioTimer?.cancel();
      _audioTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _audioProgress += step;
          if (_audioProgress >= 1.0) {
            _audioProgress = 1.0;
            _isPlayingAudio = false;
            timer.cancel();
          }
        });
      });
    }
  }

  void _showReactionSheet(BuildContext context) {
    final theme = Theme.of(context);
    final quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏'];

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Quick reaction bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: quickEmojis.map((emoji) {
                  final hasReacted = widget.message.hasUserReacted(widget.currentUserId, emoji);
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      widget.onReact?.call(emoji);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: hasReacted
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            // Actions
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Reply'),
              onTap: () {
                Navigator.of(ctx).pop();
                widget.onReply?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.of(ctx).pop();
                Clipboard.setData(ClipboardData(text: widget.message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            if (widget.canModerate)
              ListTile(
                leading: Icon(
                  widget.message.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  color: Colors.amber.shade800,
                ),
                title: Text(widget.message.isPinned ? 'Unpin message' : 'Pin message'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onPin?.call(!widget.message.isPinned);
                },
              ),
            if (widget.isMe && widget.message.deliveryStatus == MessageDeliveryStatus.sent)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onEdit?.call();
                },
              ),
            if (widget.isMe || widget.canModerate)
              ListTile(
                leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text(
                  widget.isMe ? 'Delete message' : 'Delete (Moderator)',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onDelete?.call();
                },
              ),
            if (!widget.isMe)
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                title: const Text('Report inappropriate message'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showReportDialog(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    String selectedReason = 'Spam or inappropriate content';
    final reasons = [
      'Spam or inappropriate content',
      'Harassment or hate speech',
      'Misleading announcement',
      'Financial fraud or impersonation',
      'Other violation of Idir bylaws',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((r) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selectedReason == r
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selectedReason == r ? AppColors.primary : Colors.grey,
                  size: 20,
                ),
                title: Text(r, style: const TextStyle(fontSize: 13)),
                onTap: () => setDialogState(() => selectedReason = r),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                widget.onReport?.call(selectedReason);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Report submitted to Idir leadership.'),
                  ),
                );
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaViewer(BuildContext context, String title, String url, bool isVideo) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(title, style: const TextStyle(fontSize: 16)),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          body: Center(
            child: isVideo
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_circle_fill, size: 80, color: Colors.white70),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Video playback stream',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  )
                : Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 60, color: Colors.white70),
                        SizedBox(height: 12),
                        Text('Unable to load full image', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('hh:mm a').format(widget.message.createdAt.toLocal());
    final isFailed = widget.message.deliveryStatus == MessageDeliveryStatus.failed;
    final isSending = widget.message.deliveryStatus == MessageDeliveryStatus.sending;
    final isMe = widget.isMe;

    Color bubbleColor = isMe
        ? AppColors.primary
        : theme.colorScheme.surfaceContainerHighest;

    Color textColor = isMe ? Colors.white : theme.colorScheme.onSurface;

    if (widget.message.isEmergency) {
      bubbleColor = isMe ? Colors.red.shade800 : Colors.red.shade50;
      textColor = isMe ? Colors.white : Colors.red.shade900;
    } else if (widget.message.isAnnouncement) {
      bubbleColor = isMe ? Colors.amber.shade900 : Colors.amber.shade50;
      textColor = isMe ? Colors.white : Colors.amber.shade900;
    } else if (widget.message.isContributionReminder) {
      bubbleColor = isMe ? Colors.teal.shade800 : Colors.teal.shade50;
      textColor = isMe ? Colors.white : Colors.teal.shade900;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Incoming Sender Avatar ───────────────────────────────────────
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _getRoleColor(widget.message.senderRole).withValues(alpha: 0.2),
              child: Text(
                widget.message.senderName.isNotEmpty
                    ? widget.message.senderName[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getRoleColor(widget.message.senderRole),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // ── Message Content Box ──────────────────────────────────────────
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showReactionSheet(context),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                        bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                      ),
                      border: isFailed
                          ? Border.all(color: theme.colorScheme.error, width: 1.5)
                          : (widget.message.isEmergency
                              ? Border.all(color: Colors.red.shade400, width: 1.2)
                              : null),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        // ── Pinned Indicator ──────────────────────────────────
                        if (widget.message.isPinned) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.push_pin,
                                  size: 12,
                                  color: isMe ? Colors.white70 : Colors.amber.shade800),
                              const SizedBox(width: 4),
                              Text(
                                'PINNED MESSAGE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: isMe ? Colors.white70 : Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],

                        // ── Forwarded Banner ─────────────────────────────────
                        if (widget.message.isForwarded) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.forward,
                                  size: 13,
                                  color: isMe ? Colors.white70 : theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Forwarded ${widget.message.forwardedFromName != null ? 'from ${widget.message.forwardedFromName}' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: isMe
                                      ? Colors.white70
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],

                        // ── Special Alert Badge (Announcement / Emergency) ───
                        if (widget.message.isSpecialAlert) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.black.withValues(alpha: 0.2)
                                  : (widget.message.isEmergency
                                      ? Colors.red.shade100
                                      : widget.message.isAnnouncement
                                          ? Colors.amber.shade100
                                          : Colors.teal.shade100),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.message.isEmergency
                                      ? Icons.warning_amber_rounded
                                      : widget.message.isAnnouncement
                                          ? Icons.campaign
                                          : Icons.event_note,
                                  size: 14,
                                  color: isMe
                                      ? Colors.white
                                      : (widget.message.isEmergency
                                          ? Colors.red.shade900
                                          : widget.message.isAnnouncement
                                              ? Colors.amber.shade900
                                              : Colors.teal.shade900),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  widget.message.isEmergency
                                      ? 'EMERGENCY / FUNERAL NOTICE'
                                      : widget.message.isAnnouncement
                                          ? 'OFFICIAL IDIR ANNOUNCEMENT'
                                          : 'CONTRIBUTION NOTICE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isMe
                                        ? Colors.white
                                        : (widget.message.isEmergency
                                            ? Colors.red.shade900
                                            : widget.message.isAnnouncement
                                                ? Colors.amber.shade900
                                                : Colors.teal.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // ── Sender Name & Role Badge (For Incoming Messages) ─────
                        if (!isMe) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.message.senderName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _getRoleColor(widget.message.senderRole),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.message.senderRole.isNotEmpty &&
                                  widget.message.senderRole != 'MEMBER') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(widget.message.senderRole)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.message.senderRole,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _getRoleColor(widget.message.senderRole),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],

                        // ── Quoted Reply Preview Card ────────────────────────
                        if (widget.message.hasReply) ...[
                          GestureDetector(
                            onTap: () {
                              if (widget.message.replyToId != null) {
                                widget.onTapReply?.call(widget.message.replyToId!);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.black.withValues(alpha: 0.15)
                                    : theme.colorScheme.surface.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(8),
                                border: Border(
                                  left: BorderSide(
                                    color: isMe ? Colors.white70 : AppColors.primary,
                                    width: 3.5,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.message.replyToSenderName ?? 'Reply',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isMe ? Colors.white : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.message.replyToContent ?? 'Attachment',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // ── Media Attachment Widget ──────────────────────────
                        if (widget.message.hasAttachment) ...[
                          _buildAttachmentWidget(context, isMe),
                          const SizedBox(height: 6),
                        ],

                        // ── Message Text ─────────────────────────────────────
                        if (widget.message.content.isNotEmpty) ...[
                          Text(
                            widget.message.content,
                            style: TextStyle(
                              fontSize: 14.5,
                              color: textColor,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],

                        // ── Timestamp, Edited Indicator & Status ─────────────
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.75)
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            if (widget.message.isEdited) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(edited)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: isMe
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              if (isSending)
                                const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                  ),
                                )
                              else if (isFailed)
                                InkWell(
                                  onTap: widget.onRetry,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.error_outline,
                                          size: 13, color: theme.colorScheme.error),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Retry',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.error,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.done_all,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Reactions Row Strip ──────────────────────────────────
                  if (widget.message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      children: widget.message.groupedReactions.entries.map((entry) {
                        final emoji = entry.key;
                        final count = entry.value.length;
                        final hasReacted = widget.message.hasUserReacted(widget.currentUserId, emoji);

                        return GestureDetector(
                          onTap: () => widget.onReact?.call(emoji),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasReacted
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasReacted
                                    ? AppColors.primary
                                    : theme.dividerColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 12)),
                                if (count > 1) ...[
                                  const SizedBox(width: 3),
                                  Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: hasReacted
                                          ? AppColors.primary
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentWidget(BuildContext context, bool isMe) {
    final theme = Theme.of(context);
    final msg = widget.message;
    final url = msg.attachmentUrl ?? '';
    final name = msg.attachmentName ?? 'Attachment';
    final sizeKb = (msg.attachmentSize ?? 0) > 0
        ? '${((msg.attachmentSize ?? 0) / 1024).toStringAsFixed(1)} KB'
        : '';

    if (msg.isImage) {
      return GestureDetector(
        onTap: () => _showMediaViewer(context, name, url, false),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Image.network(
                url,
                width: 220,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 220,
                  height: 120,
                  color: Colors.black12,
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 36, color: Colors.grey),
                  ),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fullscreen, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (msg.isVideo) {
      final dur = msg.attachmentDuration != null ? '${msg.attachmentDuration}s' : '';
      return GestureDetector(
        onTap: () => _showMediaViewer(context, name, url, true),
        child: Container(
          width: 220,
          height: 130,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.play_circle_filled, size: 44, color: Colors.white),
              Positioned(
                bottom: 6,
                right: 8,
                child: Text(
                  dur.isNotEmpty ? dur : 'VIDEO',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (msg.isAudioOrVoice) {
      final totalSec = msg.attachmentDuration ?? 15;
      final currentSec = (_audioProgress * totalSec).toInt();
      final timeDisplay = '${(currentSec ~/ 60)}:${(currentSec % 60).toString().padLeft(2, '0')} / ${(totalSec ~/ 60)}:${(totalSec % 60).toString().padLeft(2, '0')}';

      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.15) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_filled,
                size: 34,
                color: isMe ? Colors.white : AppColors.primary,
              ),
              onPressed: _toggleAudioPlayback,
            ),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    value: _audioProgress,
                    backgroundColor: isMe ? Colors.white24 : Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isMe ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeDisplay,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.mic,
              size: 16,
              color: isMe ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      );
    }

    // Default: PDF / Document
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.15) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            msg.isPdfOrDoc ? Icons.picture_as_pdf : Icons.insert_drive_file,
            color: msg.isPdfOrDoc ? Colors.red.shade400 : AppColors.primary,
            size: 28,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sizeKb.isNotEmpty)
                  Text(
                    sizeKb,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.download,
            size: 18,
            color: isMe ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'CHAIRPERSON':
      case 'CREATOR':
        return Colors.amber.shade800;
      case 'TREASURER':
        return Colors.teal.shade700;
      case 'SECRETARY':
        return Colors.indigo.shade600;
      case 'AUDITOR':
        return Colors.red.shade700;
      case 'COMMITTEE':
      case 'OFFICER':
        return Colors.deepPurple.shade600;
      default:
        return AppColors.primary;
    }
  }
}
