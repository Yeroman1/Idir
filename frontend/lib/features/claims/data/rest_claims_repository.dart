import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../../../../core/providers/sync_status_provider.dart';
import '../../../../core/storage/offline_cache_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../domain/models/claim.dart';
import 'claims_repository.dart';

class RestClaimsRepository implements ClaimsRepository {
  RestClaimsRepository({
    required ApiClient apiClient,
    required OfflineCacheService cacheService,
    required Ref ref,
    String? idirId,
  })  : _api = apiClient,
        _cache = cacheService,
        _ref = ref,
        _idirId = idirId {
    _streamController = StreamController<List<Claim>>.broadcast(
      onListen: () {
        _streamController.add(List.unmodifiable(_inMemoryItems));
      },
    );

    _ref.read(syncProvider.notifier).registerSyncCallback(getClaims);
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
    if (active != null && active.isNotEmpty && active != '00000000-0000-0000-0000-000000000001') {
      return active;
    }
    return null;
  }

  String get _cacheKey => 'cache_claims_${_currentIdirId ?? "none"}';
  final List<Claim> _inMemoryItems = [];
  late final StreamController<List<Claim>> _streamController;

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
      await getClaims();
    } catch (_) {}
  }

  @override
  Stream<List<Claim>> watchClaims() => _streamController.stream;

  @override
  Future<List<Claim>> getClaims() async {
    final activeId = _currentIdirId;
    if (activeId == null) {
      _inMemoryItems.clear();
      _streamController.add(const []);
      return const [];
    }
    try {
      final res = await _api.get('/idirs/$activeId/assistance/cases');
      List<dynamic> rawItems = [];
      if (res is Map<String, dynamic> && res.containsKey('items')) {
        rawItems = res['items'] as List<dynamic>? ?? [];
      } else if (res is List<dynamic>) {
        rawItems = res;
      }

      final parsed = rawItems.map((e) => _fromBackendJson(e as Map<String, dynamic>)).toList();

      _inMemoryItems.clear();
      _inMemoryItems.addAll(parsed);
      await _saveToCache(_inMemoryItems);
      _streamController.add(List.unmodifiable(_inMemoryItems));
      return List.unmodifiable(_inMemoryItems);
    } on ApiException catch (e) {
      debugPrint('[RestClaimsRepository] Live assistance cases failed (offline=${e.isOffline}): $e');
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        _inMemoryItems.clear();
        await _cache.remove(_cacheKey);
        _streamController.add(const []);
        return const [];
      }
    } catch (e) {
      debugPrint('[RestClaimsRepository] Error: $e');
    }

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
  Future<Claim?> getClaimById(String id) async {
    final all = await getClaims();
    return all.where((c) => c.id == id).firstOrNull;
  }

  @override
  Future<void> submitClaim(Claim claim) async {
    _inMemoryItems.insert(0, claim);
    await _saveToCache(_inMemoryItems);
    _streamController.add(List.unmodifiable(_inMemoryItems));

    try {
      await _api.post(
        '/idirs/$_currentIdirId/assistance/cases',
        body: {
          'caseType': claim.type.name.toUpperCase(),
          'requestedAmount': claim.requestedAmount,
          'notes': claim.description,
        },
      );
    } catch (_) {
      _ref.read(syncProvider.notifier).enqueueItem(
            title: 'Claim: ${claim.memberName} (${claim.claimNumber})',
            type: 'Assistance Claim',
          );
    }
  }

  @override
  Future<Claim> voteOnClaim({
    required String claimId,
    required String uid,
    required String name,
    required String role,
    required String decision,
    required String comment,
    int approvalsRequired = AppConstants.defaultClaimApprovalsRequired,
  }) async {
    final idx = _inMemoryItems.indexWhere((c) => c.id == claimId);
    if (idx != -1) {
      final old = _inMemoryItems[idx];
      final newApproval = ClaimApproval(
        uid: uid,
        name: name,
        role: role,
        decision: decision,
        comment: comment,
        at: DateTime.now(),
      );
      final approvals = [...old.approvals, newApproval];
      final isApproved = approvals.where((a) => a.decision == 'approved').length >= approvalsRequired;
      final isRejected = decision == 'rejected';

      final updated = old.copyWith(
        approvals: approvals,
        status: isRejected
            ? ClaimStatus.rejected
            : (isApproved ? ClaimStatus.approved : ClaimStatus.submitted),
      );
      _inMemoryItems[idx] = updated;
      await _saveToCache(_inMemoryItems);
      _streamController.add(List.unmodifiable(_inMemoryItems));

      try {
        await _api.post(
          '/idirs/$_currentIdirId/assistance/cases/$claimId/reviews',
          body: {
            'decision': decision.toUpperCase(),
            'notes': comment,
          },
        );
      } catch (_) {}

      return updated;
    }
    throw Exception('Claim not found');
  }

  @override
  Future<void> recordPayout({
    required String claimId,
    required double payoutAmount,
    required String recordedByUid,
    required String recordedByName,
  }) async {
    final idx = _inMemoryItems.indexWhere((c) => c.id == claimId);
    if (idx != -1) {
      final updated = _inMemoryItems[idx].copyWith(
        status: ClaimStatus.paid,
        payoutAmount: payoutAmount,
        paidAt: DateTime.now(),
      );
      _inMemoryItems[idx] = updated;
      await _saveToCache(_inMemoryItems);
      _streamController.add(List.unmodifiable(_inMemoryItems));
    }

    try {
      await _api.post(
        '/idirs/$_idirId/assistance/cases/$claimId/disbursements',
        body: {'amount': payoutAmount},
      );
    } catch (_) {}
  }

  @override
  Future<String> generateNextClaimNumber() async {
    final year = DateTime.now().year;
    final all = await getClaims();
    int highest = 0;
    for (final c in all) {
      if (c.claimNumber.startsWith('CLM-$year-')) {
        final numPart = int.tryParse(c.claimNumber.replaceFirst('CLM-$year-', ''));
        if (numPart != null && numPart > highest) {
          highest = numPart;
        }
      }
    }
    return 'CLM-$year-${(highest + 1).toString().padLeft(3, '0')}';
  }

  Claim _fromBackendJson(Map<String, dynamic> json) {
    final member = json['membership'] as Map<String, dynamic>?;
    final user = member?['user'] as Map<String, dynamic>?;

    final memberName = user?['fullName'] as String? ?? 'Community Member';
    final memberId = member?['memberNumber'] as String? ?? 'BM-001';
    final requestedAmount = double.tryParse(json['requestedAmount']?.toString() ?? '0') ?? 0.0;
    final date = DateTime.tryParse(json['incidentDate']?.toString() ?? '') ?? DateTime.now();

    final statusStr = (json['status'] as String? ?? '').toUpperCase();
    final status = switch (statusStr) {
      'APPROVED' => ClaimStatus.approved,
      'REJECTED' => ClaimStatus.rejected,
      'DISBURSED' || 'PAID' => ClaimStatus.paid,
      _ => ClaimStatus.submitted,
    };

    return Claim(
      id: json['id'] as String? ?? const Uuid().v4(),
      claimNumber: json['caseNumber'] as String? ?? 'CLM-${date.year}-001',
      memberId: memberId,
      memberName: memberName,
      type: ClaimTypeX.fromString(json['caseType'] as String?),
      description: json['notes'] as String? ?? 'Mutual aid assistance request',
      requestedAmount: requestedAmount > 0 ? requestedAmount : 5000.0,
      status: status,
      submittedBy: json['createdById'] as String? ?? 'officer',
      submittedByName: memberName,
      createdAt: date,
      approvals: const [],
    );
  }

  Future<List<Claim>> _loadFromCache() async {
    final cached = await _cache.read(_cacheKey);
    if (cached is List<dynamic>) {
      return cached.map((e) => Claim.fromMap((e as Map<String, dynamic>)['id'] as String? ?? '', e)).toList();
    }
    return [];
  }

  Future<void> _saveToCache(List<Claim> list) async {
    final jsonList = list.map((c) {
      final map = c.toMap();
      map['id'] = c.id;
      return map;
    }).toList();
    await _cache.save(_cacheKey, jsonList);
  }
}
