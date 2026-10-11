import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/sync_status_provider.dart';
import '../theme/app_theme.dart';

/// Global banner shown whenever the application is offline or actively synchronizing.
class OfflineIndicatorBar extends ConsumerWidget {
  const OfflineIndicatorBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);

    if (!syncState.isOffline && !syncState.isSyncing) {
      return const SizedBox.shrink();
    }

    final isOffline = syncState.isOffline;
    final isSyncing = syncState.isSyncing;

    final bgColor = isOffline
        ? const Color(0xFFD97706) // Warm amber / terracotta
        : AppColors.primary;

    return Material(
      color: bgColor,
      child: InkWell(
        onTap: () => showOfflineSyncModal(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SafeArea(
            bottom: false,
            top: false,
            child: Row(
              children: [
                if (isSyncing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isSyncing
                        ? 'Synchronizing offline records with cloud…'
                        : 'Offline Mode • ${syncState.pendingCount} ${syncState.pendingCount == 1 ? "change" : "changes"} queued locally',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isOffline) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      ref.read(syncProvider.notifier).triggerSync();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Sync',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the Offline Synchronization diagnostic bottom sheet.
void showOfflineSyncModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _OfflineSyncModalContent(),
  );
}

class _OfflineSyncModalContent extends ConsumerWidget {
  const _OfflineSyncModalContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final syncState = ref.watch(syncProvider);
    final df = DateFormat('dd MMM yyyy, HH:mm:ss');

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (syncState.isOffline
                          ? AppColors.warning
                          : AppColors.success)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  syncState.isOffline
                      ? Icons.cloud_off_rounded
                      : Icons.cloud_done_rounded,
                  color: syncState.isOffline
                      ? AppColors.warning
                      : AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline Synchronization Center',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      syncState.isOffline
                          ? 'Operating in local offline storage'
                          : 'Connected to Idir cloud database',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Diagnostics Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                _StatusRow(
                  label: 'Connection Status',
                  value: syncState.isOffline ? 'Offline' : 'Online',
                  color: syncState.isOffline
                      ? AppColors.warning
                      : AppColors.success,
                  icon: syncState.isOffline
                      ? Icons.wifi_off_rounded
                      : Icons.wifi_rounded,
                ),
                const Divider(height: 20),
                _StatusRow(
                  label: 'Pending Sync Queue',
                  value: '${syncState.pendingCount} operations',
                  color: syncState.pendingCount > 0
                      ? AppColors.warning
                      : AppColors.primary,
                  icon: Icons.pending_actions_rounded,
                ),
                const Divider(height: 20),
                _StatusRow(
                  label: 'Last Successful Sync',
                  value: df.format(syncState.lastSyncedAt),
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  icon: Icons.history_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pending Items List (if any)
          if (syncState.pendingQueue.isNotEmpty) ...[
            Text(
              'QUEUED CHANGES (${syncState.pendingCount})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: syncState.pendingQueue.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16),
                itemBuilder: (ctx, i) {
                  final item = syncState.pendingQueue[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.receipt_long, size: 18),
                    title: Text(item.title,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      '${item.type} • ${DateFormat("HH:mm").format(item.timestamp)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(
                      Icons.schedule,
                      size: 14,
                      color: AppColors.warning,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Offline Simulation Switch
          SwitchListTile(
            title: const Text(
              'Simulate Offline Field Mode',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Test local buffering and receipt creation without network connectivity',
              style: TextStyle(fontSize: 12),
            ),
            value: syncState.isOfflineSimulated,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              ref.read(syncProvider.notifier).toggleOffline();
            },
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              if (syncState.pendingCount > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(syncProvider.notifier).clearPendingQueue();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Clear Queue'),
                  ),
                ),
              if (syncState.pendingCount > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: syncState.isSyncing
                      ? null
                      : () async {
                          await ref.read(syncProvider.notifier).triggerSync();
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('All records synchronized successfully!'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  icon: syncState.isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(
                    syncState.isSyncing ? 'Synchronizing…' : 'Sync All Changes',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
