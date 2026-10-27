import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onRetry,
    this.onEdit,
    this.onDelete,
  });

  final ChatMessage message;
  final bool isMe;
  final VoidCallback onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  void _showActionSheet(BuildContext context) {
    if (!isMe || message.deliveryStatus != MessageDeliveryStatus.sent) return;

    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit message'),
              onTap: () {
                Navigator.of(ctx).pop();
                onEdit?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text('Delete message', style: TextStyle(color: theme.colorScheme.error)),
              onTap: () {
                Navigator.of(ctx).pop();
                onDelete?.call();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('hh:mm a').format(message.createdAt.toLocal());
    final isFailed = message.deliveryStatus == MessageDeliveryStatus.failed;
    final isSending = message.deliveryStatus == MessageDeliveryStatus.sending;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Incoming Sender Avatar ───────────────────────────────────────
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _getRoleColor(message.senderRole).withValues(alpha: 0.2),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getRoleColor(message.senderRole),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // ── Message Content Box ──────────────────────────────────────────
          Flexible(
            child: GestureDetector(
              onLongPress: isMe && !isSending && !isFailed
                  ? () => _showActionSheet(context)
                  : null,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                  ),
                  border: isFailed
                      ? Border.all(color: theme.colorScheme.error, width: 1.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // ── Sender Name & Role Badge (For Incoming Messages) ─────
                    if (!isMe) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              message.senderName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getRoleColor(message.senderRole),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (message.senderRole.isNotEmpty &&
                              message.senderRole != 'MEMBER') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getRoleColor(message.senderRole)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                message.senderRole,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: _getRoleColor(message.senderRole),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    // ── Message Text ─────────────────────────────────────────
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 15,
                        color: isMe
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // ── Timestamp, Edited Indicator & Status ─────────────────
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.7)
                                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        if (message.isEdited) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(edited)',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.65)
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
                              onTap: onRetry,
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
                          else ...[
                            const Icon(
                              Icons.done,
                              size: 12,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 2),
                            // Popup menu for Edit and Delete
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_horiz,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Message options',
                              onSelected: (val) {
                                if (val == 'edit') onEdit?.call();
                                if (val == 'delete') onDelete?.call();
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  height: 36,
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 16),
                                      SizedBox(width: 8),
                                      Text('Edit', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  height: 36,
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
