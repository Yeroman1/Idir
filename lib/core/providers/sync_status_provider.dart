import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncStatus {
  synced,
  syncing,
  offline,
  error,
}

class PendingSyncItem {
  const PendingSyncItem({
    required this.id,
    required this.title,
    required this.type,
    required this.timestamp,
  });

  final String id;
  final String title;
  final String type;
  final DateTime timestamp;
}

class SyncState {
  const SyncState({
    required this.status,
    required this.isOfflineSimulated,
    required this.lastSyncedAt,
    required this.pendingQueue,
    this.errorMessage,
  });

  final SyncStatus status;
  final bool isOfflineSimulated;
  final DateTime lastSyncedAt;
  final List<PendingSyncItem> pendingQueue;
  final String? errorMessage;

  int get pendingCount => pendingQueue.length;
  bool get isOffline => status == SyncStatus.offline || isOfflineSimulated;
  bool get isSyncing => status == SyncStatus.syncing;
  bool get isSynced => status == SyncStatus.synced && !isOffline;

  SyncState copyWith({
    SyncStatus? status,
    bool? isOfflineSimulated,
    DateTime? lastSyncedAt,
    List<PendingSyncItem>? pendingQueue,
    String? Function()? errorMessage,
  }) {
    return SyncState(
      status: status ?? this.status,
      isOfflineSimulated: isOfflineSimulated ?? this.isOfflineSimulated,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingQueue: pendingQueue ?? this.pendingQueue,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier()
      : super(SyncState(
          status: SyncStatus.synced,
          isOfflineSimulated: false,
          lastSyncedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          pendingQueue: const [],
        ));

  void toggleOffline() {
    final nextOffline = !state.isOfflineSimulated;
    if (nextOffline) {
      state = state.copyWith(
        isOfflineSimulated: true,
        status: SyncStatus.offline,
        pendingQueue: [
          ...state.pendingQueue,
          if (state.pendingQueue.isEmpty)
            PendingSyncItem(
              id: 'q-${DateTime.now().millisecondsSinceEpoch}',
              title: 'Offline Dues Receipt Queue (ETB 300)',
              type: 'Contribution',
              timestamp: DateTime.now(),
            ),
        ],
      );
    } else {
      state = state.copyWith(
        isOfflineSimulated: false,
        status: SyncStatus.synced,
      );
      // Auto trigger sync on reconnect
      triggerSync();
    }
  }

  Future<void> triggerSync() async {
    if (state.isSyncing) return;

    state = state.copyWith(
      status: SyncStatus.syncing,
      errorMessage: () => null,
    );

    // Simulate async sync network call
    await Future.delayed(const Duration(milliseconds: 1400));

    state = state.copyWith(
      status: SyncStatus.synced,
      isOfflineSimulated: false,
      lastSyncedAt: DateTime.now(),
      pendingQueue: const [],
      errorMessage: () => null,
    );
  }

  void enqueueItem({required String title, required String type}) {
    final newItem = PendingSyncItem(
      id: 'item-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: type,
      timestamp: DateTime.now(),
    );

    final updated = [...state.pendingQueue, newItem];
    state = state.copyWith(
      pendingQueue: updated,
      status: state.isOffline ? SyncStatus.offline : state.status,
    );
  }

  void clearPendingQueue() {
    state = state.copyWith(pendingQueue: const []);
  }
}

/// Primary sync manager provider with queue and offline simulation state.
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier();
});

/// Backwards compatibility provider for `SyncStatus`.
final syncStatusProvider = Provider<SyncStatus>((ref) {
  return ref.watch(syncProvider).status;
});
