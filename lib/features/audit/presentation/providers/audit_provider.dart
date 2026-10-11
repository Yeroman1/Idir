import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/audit_log_repository.dart';
import '../../domain/models/audit_log_entry.dart';

final auditCollectionFilterProvider = StateProvider<String?>((ref) => null);
final auditSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredAuditLogsProvider = Provider<List<AuditLogEntry>>((ref) {
  final logsAsync = ref.watch(auditLogsStreamProvider);
  final filter = ref.watch(auditCollectionFilterProvider);
  final query = ref.watch(auditSearchQueryProvider).trim().toLowerCase();
  final all = logsAsync.value ?? [];

  return all.where((entry) {
    if (filter != null && entry.targetCollection != filter) {
      return false;
    }
    if (query.isNotEmpty) {
      final matchesSummary = entry.summary.toLowerCase().contains(query);
      final matchesActor = entry.actorName.toLowerCase().contains(query);
      final matchesAction = entry.action.toLowerCase().contains(query);
      final matchesTarget = entry.targetId.toLowerCase().contains(query);
      return matchesSummary || matchesActor || matchesAction || matchesTarget;
    }
    return true;
  }).toList();
});

class AuditVerificationNotifier
    extends StateNotifier<AsyncValue<AuditVerificationResult?>> {
  AuditVerificationNotifier(this._repository)
      : super(const AsyncValue.data(null));

  final AuditLogRepository _repository;

  Future<AuditVerificationResult> runVerification() async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.verifyChain();
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final auditVerificationNotifierProvider = StateNotifierProvider<
    AuditVerificationNotifier, AsyncValue<AuditVerificationResult?>>((ref) {
  final repo = ref.watch(auditLogRepositoryProvider);
  return AuditVerificationNotifier(repo);
});
