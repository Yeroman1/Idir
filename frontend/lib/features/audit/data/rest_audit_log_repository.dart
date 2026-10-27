import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../../../../core/providers/sync_status_provider.dart';
import '../../../../core/storage/offline_cache_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../domain/models/audit_log_entry.dart';
import 'audit_log_repository.dart';

class RestAuditLogRepository implements AuditLogRepository {
  RestAuditLogRepository({
    required ApiClient apiClient,
    required OfflineCacheService cacheService,
    required Ref ref,
    String? idirId,
  })  : _api = apiClient,
        _cache = cacheService,
        _ref = ref,
        _idirId = idirId {
    _streamController = StreamController<List<AuditLogEntry>>.broadcast(
      onListen: () {
        _streamController.add(List.unmodifiable(_inMemoryItems));
      },
    );

    _ref.read(syncProvider.notifier).registerSyncCallback(getAuditLogs);
    _init();
  }

  final ApiClient _api;
  final OfflineCacheService _cache;
  final Ref _ref;
  final String? _idirId;

  String? get _currentIdirId {
    final active = _ref.read(currentActiveIdirProvider)?.idirId ??
        _ref.read(currentUserProvider)?.idirId ??
        _idirId;
    if (active != null &&
        active.isNotEmpty &&
        active != '00000000-0000-0000-0000-000000000001') {
      return active;
    }
    return null;
  }

  String get _cacheKey => 'cache_audit_logs_${_currentIdirId ?? "none"}';
  final List<AuditLogEntry> _inMemoryItems = [];
  late final StreamController<List<AuditLogEntry>> _streamController;

  Future<void> _init() async {
    final activeId = _currentIdirId;
    if (activeId == null) {
      _inMemoryItems.clear();
      _streamController.add(const []);
      return;
    }

    final cached = await _loadFromCache();
    if (cached.isNotEmpty) {
      _inMemoryItems.clear();
      _inMemoryItems.addAll(cached);
      _streamController.add(List.unmodifiable(_inMemoryItems));
    }

    try {
      await getAuditLogs();
    } catch (_) {}
  }

  @override
  Stream<List<AuditLogEntry>> watchAuditLogs() => _streamController.stream;

  @override
  Future<List<AuditLogEntry>> getAuditLogs() async {
    final activeId = _currentIdirId;
    if (activeId == null) {
      _inMemoryItems.clear();
      _streamController.add(const []);
      return const [];
    }
    try {
      final res = await _api.get('/idirs/$activeId/audit', queryParams: {'limit': 100});
      List<dynamic> rawItems = [];
      if (res is Map<String, dynamic> && res.containsKey('items')) {
        rawItems = res['items'] as List<dynamic>? ?? [];
      } else if (res is List<dynamic>) {
        rawItems = res;
      }

      final parsed = _buildHashChain(rawItems);

      _inMemoryItems.clear();
      _inMemoryItems.addAll(parsed);
      await _saveToCache(_inMemoryItems);
      _streamController.add(List.unmodifiable(_inMemoryItems));
      return List.unmodifiable(_inMemoryItems);
    } on ApiException catch (e) {
      debugPrint('[RestAuditLogRepository] Fetching live audit logs failed (offline=${e.isOffline}): $e');
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        _inMemoryItems.clear();
        await _cache.remove(_cacheKey);
        _streamController.add(const []);
        return const [];
      }
    } catch (e) {
      debugPrint('[RestAuditLogRepository] Error: $e');
    }

    // Fallback to offline cached data if available
    final cached = await _loadFromCache();
    if (cached.isNotEmpty) {
      _inMemoryItems.clear();
      _inMemoryItems.addAll(cached);
      _streamController.add(List.unmodifiable(_inMemoryItems));
      return List.unmodifiable(_inMemoryItems);
    }

    return List.unmodifiable(_inMemoryItems);
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
    final prevHash = _inMemoryItems.isNotEmpty
        ? _inMemoryItems.last.hash
        : genesisHash;
    final now = DateTime.now();

    final entry = AuditLogEntry.create(
      id: 'log_${now.millisecondsSinceEpoch}',
      actorUid: actorUid,
      actorName: actorName,
      actorRole: actorRole,
      action: action,
      targetCollection: targetCollection,
      targetId: targetId,
      summary: summary,
      createdAt: now,
      prevHash: prevHash,
    );

    _inMemoryItems.add(entry);
    await _saveToCache(_inMemoryItems);
    _streamController.add(List.unmodifiable(_inMemoryItems));
    return entry;
  }

  @override
  Future<AuditVerificationResult> verifyChain() async {
    final items = await getAuditLogs();
    if (items.isEmpty) {
      return const AuditVerificationResult(
        isValid: true,
        totalEntries: 0,
        verifiedEntries: 0,
      );
    }

    final chronological = List<AuditLogEntry>.from(items)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (int i = 0; i < chronological.length; i++) {
      final entry = chronological[i];
      final expectedPrev = i == 0 ? genesisHash : chronological[i - 1].hash;

      if (entry.prevHash != expectedPrev) {
        return AuditVerificationResult(
          isValid: false,
          totalEntries: chronological.length,
          verifiedEntries: i,
          brokenEntryIndex: i,
          brokenEntryId: entry.id,
          errorMessage: 'Chain broken at block $i (${entry.id})',
        );
      }

      final expectedHash = entry.computeExpectedHash();
      if (entry.hash != expectedHash) {
        return AuditVerificationResult(
          isValid: false,
          totalEntries: chronological.length,
          verifiedEntries: i,
          brokenEntryIndex: i,
          brokenEntryId: entry.id,
          errorMessage: 'Hash mismatch at block $i (${entry.id})',
        );
      }
    }

    return AuditVerificationResult(
      isValid: true,
      totalEntries: chronological.length,
      verifiedEntries: chronological.length,
    );
  }

  List<AuditLogEntry> _buildHashChain(List<dynamic> rawItems) {
    // Sort oldest first to build linear cryptographic hash chain
    final sorted = List<Map<String, dynamic>>.from(
      rawItems.whereType<Map<String, dynamic>>(),
    )..sort((a, b) {
        final tA = DateTime.tryParse(a['timestamp'] as String? ?? '') ?? DateTime(0);
        final tB = DateTime.tryParse(b['timestamp'] as String? ?? '') ?? DateTime(0);
        return tA.compareTo(tB);
      });

    final List<AuditLogEntry> chain = [];
    String prevHash = genesisHash;

    for (final item in sorted) {
      final id = item['id'] as String? ?? '';
      final actor = item['actor'] as Map<String, dynamic>?;
      final actorId = item['actorId'] as String? ?? actor?['id'] as String? ?? 'system';
      final actorName = actor?['fullName'] as String? ?? 'System';
      final action = item['action'] as String? ?? 'UNKNOWN';
      final entityType = item['entityType'] as String? ?? 'System';
      final entityId = item['entityId'] as String? ?? '';
      final timestamp = DateTime.tryParse(item['timestamp'] as String? ?? '') ?? DateTime.now();

      String summary = '$action on $entityType';
      if (item['safeMetadata'] is Map<String, dynamic>) {
        final meta = item['safeMetadata'] as Map<String, dynamic>;
        if (meta['name'] != null) {
          summary += ' (${meta['name']})';
        }
      }

      final entry = AuditLogEntry.create(
        id: id,
        actorUid: actorId,
        actorName: actorName,
        actorRole: 'OFFICER',
        action: action,
        targetCollection: entityType,
        targetId: entityId,
        summary: summary,
        createdAt: timestamp,
        prevHash: prevHash,
      );

      prevHash = entry.hash;
      chain.add(entry);
    }

    // Return in reverse chronological order for UI display
    return chain.reversed.toList();
  }

  Future<void> _saveToCache(List<AuditLogEntry> items) async {
    try {
      final mapList = items
          .map((e) => {
                'id': e.id,
                'actorUid': e.actorUid,
                'actorName': e.actorName,
                'actorRole': e.actorRole,
                'action': e.action,
                'targetCollection': e.targetCollection,
                'targetId': e.targetId,
                'summary': e.summary,
                'createdAt': e.createdAt.toIso8601String(),
                'prevHash': e.prevHash,
                'hash': e.hash,
              })
          .toList();
      await _cache.save(_cacheKey, mapList);
    } catch (_) {}
  }

  Future<List<AuditLogEntry>> _loadFromCache() async {
    try {
      final data = await _cache.read(_cacheKey);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((m) => AuditLogEntry.fromMap(m['id'] as String? ?? '', m))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
