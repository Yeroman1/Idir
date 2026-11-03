import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../providers/chat_provider.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({
    super.key,
    required this.idirId,
    required this.idirName,
  });

  final String idirId;
  final String idirName;

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  String _memberSearch = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final activeIdirState = ref.watch(activeIdirProvider);
    final activeMembership = activeIdirState.activeIdir;
    final chatState = ref.watch(chatNotifierProvider(widget.idirId));
    final chatNotifier = ref.read(chatNotifierProvider(widget.idirId).notifier);

    final membersAsync = ref.watch(membersStreamProvider);
    final allMembers = membersAsync.valueOrNull ?? [];

    final filteredMembers = allMembers.where((m) {
      if (_memberSearch.isEmpty) return true;
      final q = _memberSearch.toLowerCase();
      return m.fullName.toLowerCase().contains(q) ||
          m.memberId.toLowerCase().contains(q) ||
          m.phone.toLowerCase().contains(q);
    }).toList();

    final effectiveRole = activeMembership?.role ?? currentUser?.role ?? UserRole.member;
    final isLeader = effectiveRole.canPostAnnouncement;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Idir Group Info'),
        actions: [
          IconButton(
            icon: Icon(
              chatState.isMuted ? Icons.notifications_off : Icons.notifications_active,
              color: chatState.isMuted ? Colors.amber.shade700 : null,
            ),
            tooltip: chatState.isMuted ? 'Unmute chat' : 'Mute chat',
            onPressed: () => chatNotifier.toggleMuteChat(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ── Header Profile Card ──────────────────────────────────────────
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    widget.idirName.isNotEmpty ? widget.idirName[0].toUpperCase() : 'I',
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.idirName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (activeMembership?.community != null || activeMembership?.location != null) ...[
                  Text(
                    [
                      if (activeMembership?.community != null) activeMembership!.community!,
                      if (activeMembership?.location != null) activeMembership!.location!,
                    ].join(' • '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  '${allMembers.isNotEmpty ? allMembers.length : "Verified"} Members • Isolated Community Chat',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Quick Action Tiles ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Mute Notifications'),
                    subtitle: Text(
                      chatState.isMuted
                          ? 'You will not receive sound or banners for this Idir chat.'
                          : 'Receive notifications for new messages and mentions.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    secondary: Icon(
                      chatState.isMuted ? Icons.volume_off : Icons.volume_up,
                      color: chatState.isMuted ? Colors.orange : AppColors.primary,
                    ),
                    value: chatState.isMuted,
                    onChanged: (_) => chatNotifier.toggleMuteChat(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined, color: AppColors.primary),
                    title: const Text('Community Bylaws & Chat Rules'),
                    subtitle: const Text('View funeral coverage rules and respectful chat etiquette'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showBylawsDialog(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Pinned Messages Section ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ExpansionTile(
                leading: Icon(Icons.push_pin, color: Colors.amber.shade800),
                title: Text(
                  'Pinned Messages (${chatState.pinnedMessages.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text('Important notices & leadership announcements', style: TextStyle(fontSize: 11)),
                children: [
                  if (chatState.pinnedMessages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No pinned messages yet. Leaders can pin important messages from the chat.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...chatState.pinnedMessages.map((msg) {
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.amber.shade100,
                          child: Text(
                            msg.senderName.isNotEmpty ? msg.senderName[0] : 'U',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ),
                        title: Text(
                          msg.content.isNotEmpty ? msg.content : (msg.attachmentName ?? 'Attachment'),
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${msg.senderName} (${msg.senderRole})',
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: isLeader
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                tooltip: 'Unpin message',
                                onPressed: () => chatNotifier.pinMessage(msg.id, false),
                              )
                            : null,
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Members Section Header & Search ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MEMBERS (${filteredMembers.length})',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (isLeader)
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Use Members tab to invite or modify roles.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('Manage', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search members...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _memberSearch = val.trim()),
            ),
          ),
          const SizedBox(height: 8),

          // ── Members List ─────────────────────────────────────────────────
          if (filteredMembers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text('No members found', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...filteredMembers.map((member) {
              final isCurrent = currentUser?.uid == member.id || currentUser?.memberId == member.memberId;
              return ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : 'M',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('You', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  'ID: ${member.memberId.isNotEmpty ? member.memberId : "Active"} • ${member.phone}',
                  style: const TextStyle(fontSize: 11),
                ),
              );
            }),

          const SizedBox(height: 24),
          // ── Security & Privacy Footer Notice ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Idir Connect Isolated Privacy: Only verified members can participate.',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showBylawsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel, color: AppColors.primary),
            SizedBox(width: 8),
            Flexible(child: Text('Idir Bylaws & Rules', style: TextStyle(fontSize: 17))),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. General Code of Conduct',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '• All members are expected to communicate respectfully and constructively.\n'
                '• Harassment, inappropriate language, or discriminatory behavior will result in suspension.',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 10),
              Text(
                '2. Funeral & Emergency Support',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '• Immediate family coverage applies to registered dependents.\n'
                '• Official emergency notices must be verified and announced by the Chairperson or Secretary.',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 10),
              Text(
                '3. Dues & Contributions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '• Monthly contributions are due on the designated schedule.\n'
                '• Financial reminders in group chat are general broadcasts without disclosing individual member balances.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

