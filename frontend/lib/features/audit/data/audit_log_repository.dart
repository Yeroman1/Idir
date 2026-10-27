import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/active_idir_provider.dart';
import '../../../core/storage/offline_cache_service.dart';
import '../domain/models/audit_log_entry.dart';
import 'rest_audit_log_repository.dart';

abstract class AuditLogRepository {
  Stream<List<AuditLogEntry>> watchAuditLogs();
  Future<List<AuditLogEntry>> getAuditLogs();
  Future<AuditLogEntry> log({
    required String actorUid,
    required String actorName,
    required String actorRole,
    required String action,
    required String targetCollection,
    required String targetId,
    required String summary,
  });
  Future<AuditVerificationResult> verifyChain();
}

class FirestoreAuditLogRepository implements AuditLogRepository {
  FirestoreAuditLogRepository({FirebaseFirestore? firestore}) : _fs = firestore {
    _initLocalChain();
  }

  final FirebaseFirestore? _fs;
  final List<AuditLogEntry> _localCache = [];
  final _streamController = StreamController<List<AuditLogEntry>>.broadcast();

  void _initLocalChain() {
    // No mock demo data in production real application
  }

  /// Isolated test helper strictly for offline unit tests
  void seedForTest() {
    final now = DateTime.now();

    final e1 = AuditLogEntry.create(
      id: 'log_001',
      actorUid: 'system',
      actorName: 'System Genesis',
      actorRole: 'system',
      action: 'association_initialized',
      targetCollection: 'settings',
      targetId: 'main',
      summary: 'Association registry and cryptographic ledger initialized',
      createdAt: now.subtract(const Duration(days: 10)),
      prevHash: genesisHash,
    );

    final e2 = AuditLogEntry.create(
      id: 'log_002',
      actorUid: 'test_chair',
      actorName: 'Test Chair',
      actorRole: 'chairperson',
      action: 'member_created',
      targetCollection: 'members',
      targetId: 'MEM-001',
      summary: 'Registered founding member',
      createdAt: now.subtract(const Duration(days: 8)),
      prevHash: e1.hash,
    );

    final e3 = AuditLogEntry.create(
      id: 'log_003',
      actorUid: 'test_treasurer',
      actorName: 'Test Treasurer',
      actorRole: 'treasurer',
      action: 'contribution_recorded',
      targetCollection: 'contributions',
      targetId: 'REC-2024-001',
      summary: 'Recorded monthly dues contribution 50 ETB',
      createdAt: now.subtract(const Duration(days: 5)),
      prevHash: e2.hash,
    );

    final e4 = AuditLogEntry.create(
      id: 'log_004',
      actorUid: 'test_member',
      actorName: 'Test Member',
      actorRole: 'member',
      action: 'claim_submitted',
      targetCollection: 'claims',
      targetId: 'CLM-2024-001',
      summary: 'Submitted funeral mutual-aid claim for 3,000 ETB',
      createdAt: now.subtract(const Duration(days: 3)),
      prevHash: e3.hash,
    );

    final e5 = AuditLogEntry.create(
      id: 'log_005',
      actorUid: 'test_chair',
      actorName: 'Test Chair',
      actorRole: 'chairperson',
      action: 'claim_approved',
      targetCollection: 'claims',
      targetId: 'CLM-2024-002',
      summary: 'Approved claim for 1,500 ETB',
      createdAt: now.subtract(const Duration(days: 1)),
      prevHash: e4.hash,
    );

    _localCache.clear();
    _localCache.addAll([e1, e2, e3, e4, e5]);
  }

  @override
  Stream<List<AuditLogEntry>> watchAuditLogs() async* {
    final fs = _fs;
    if (fs != null) {
      try {
        final stream = fs
            .collection(AppConstants.colAuditLogs)
            .orderBy('createdAt', descending: true)
            .snapshots();

        await for (final snapshot in stream) {
          if (snapshot.docs.isNotEmpty) {
            final list = snapshot.docs
                .map((d) => AuditLogEntry.fromMap(d.id, d.data()))
                .toList();
            yield list;
            continue;
          }
          yield List.unmodifiable(_localCache.reversed.toList());
        }
        return;
      } catch (e) {
        debugPrint('Firestore watchAuditLogs fallback: $e');
      }
    }

    yield List.unmodifiable(_localCache.reversed.toList());
    yield* _streamController.stream;
  }

  @override
  Future<List<AuditLogEntry>> getAuditLogs() async {
    final fs = _fs;
    if (fs != null) {
      try {
        final snapshot = await fs
            .collection(AppConstants.colAuditLogs)
            .orderBy('createdAt', descending: true)
            .get();
        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs
              .map((d) => AuditLogEntry.fromMap(d.id, d.data()))
              .toList();
        }
      } catch (e) {
        debugPrint('Firestore getAuditLogs fallback: $e');
      }
    }
    return List.unmodifiable(_localCache.reversed.toList());
  }

  @override
  Future<AuditLogEntry> log({
    required String actorUid,
    required String actorName,
    required String actorRole,
    required String action,
    required String targetCollection,
    required String targetId,
    required String summary,
  }) async {
    // 1. Get the most recent chronologically logged entry's hash
    String previousHash = genesisHash;
    if (_localCache.isNotEmpty) {
      previousHash = _localCache.last.hash;
    }

    final now = DateTime.now();
    final newEntry = AuditLogEntry.create(
      id: const Uuid().v4(),
      actorUid: actorUid,
      actorName: actorName,
      actorRole: actorRole,
      action: action,
      targetCollection: targetCollection,
      targetId: targetId,
      summary: summary,
      createdAt: now,
      prevHash: previousHash,
    );

    final fs = _fs;
    if (fs != null) {
      try {
        await fs
            .collection(AppConstants.colAuditLogs)
            .doc(newEntry.id)
            .set(newEntry.toMap());
      } catch (e) {
        debugPrint('Firestore log append fallback: $e');
      }
    }

    _localCache.add(newEntry);
    _streamController.add(List.unmodifiable(_localCache.reversed.toList()));

    return newEntry;
  }

  @override
  Future<AuditVerificationResult> verifyChain() async {
    // Recompute the entire chain in chronological ascending order
    final List<AuditLogEntry> chronological = List.from(_localCache)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (chronological.isEmpty) {
      return const AuditVerificationResult(
        isValid: true,
        totalEntries: 0,
        verifiedEntries: 0,
      );
    }

    for (int i = 0; i < chronological.length; i++) {
      final entry = chronological[i];

      // 1. Verify genesis linkage
      if (i == 0) {
        if (entry.prevHash != genesisHash) {
          return AuditVerificationResult(
            isValid: false,
            totalEntries: chronological.length,
            verifiedEntries: i,
            brokenEntryIndex: i,
            brokenEntryId: entry.id,
            errorMessage: 'Genesis block broken: Expected genesis hash $genesisHash but found ${entry.prevHash}',
          );
        }
      } else {
        // 2. Verify hash chain link with preceding entry
        final previousEntry = chronological[i - 1];
        if (entry.prevHash != previousEntry.hash) {
          return AuditVerificationResult(
            isValid: false,
            totalEntries: chronological.length,
            verifiedEntries: i,
            brokenEntryIndex: i,
            brokenEntryId: entry.id,
            errorMessage: 'Hash chain link broken at index $i: prevHash does not match entry ${previousEntry.id} hash.',
          );
        }
      }

      // 3. Verify cryptographic SHA-256 integrity of current block payload
      final expectedHash = entry.computeExpectedHash();
      if (entry.hash != expectedHash) {
        return AuditVerificationResult(
          isValid: false,
          totalEntries: chronological.length,
          verifiedEntries: i,
          brokenEntryIndex: i,
          brokenEntryId: entry.id,
          errorMessage: 'Payload tampering detected at index $i (${entry.id}): Stored hash ${entry.hash} != expected $expectedHash',
        );
      }
    }

    return AuditVerificationResult(
      isValid: true,
      totalEntries: chronological.length,
      verifiedEntries: chronological.length,
    );
  }
}

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  final activeIdirId = ref.watch(activeIdirIdProvider);
  return RestAuditLogRepository(
    apiClient: apiClient,
    cacheService: cache,
    ref: ref,
    idirId: activeIdirId,
  );
});

final auditLogsStreamProvider = StreamProvider<List<AuditLogEntry>>((ref) {
  final repo = ref.watch(auditLogRepositoryProvider);
  return repo.watchAuditLogs();
});
