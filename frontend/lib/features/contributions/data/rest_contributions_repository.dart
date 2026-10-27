import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../../../../core/providers/sync_status_provider.dart';
import '../../../../core/storage/offline_cache_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../members/data/members_repository.dart';
import '../domain/models/contribution.dart';
import '../domain/services/balance_calculator_service.dart';
import 'contributions_repository.dart';

class RestContributionsRepository implements ContributionsRepository {
  RestContributionsRepository({
    required ApiClient apiClient,
    required OfflineCacheService cacheService,
    required Ref ref,
    required MembersRepository membersRepository,
    BalanceCalculatorService balanceCalculator = const BalanceCalculatorService(),
    String? idirId,
  })  : _api = apiClient,
        _cache = cacheService,
        _ref = ref,
        _membersRepository = membersRepository,
        _balanceCalculator = balanceCalculator,
        _idirId = idirId {
    _streamController = StreamController<List<Contribution>>.broadcast(
      onListen: () {
        _streamController.add(List.unmodifiable(_inMemoryItems));
      },
    );

    // Register with sync provider so when user taps Sync or reconnects, we refresh
    _ref.read(syncProvider.notifier).registerSyncCallback(getContributions);
    // Initial fetch (load cached first, then live in background)
    _init();
  }

  final ApiClient _api;
  final OfflineCacheService _cache;
  final Ref _ref;
  final MembersRepository _membersRepository;
  final BalanceCalculatorService _balanceCalculator;
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

  String get _cacheKey => 'cache_contributions_${_currentIdirId ?? "none"}';
  final List<Contribution> _inMemoryItems = [];
  late final StreamController<List<Contribution>> _streamController;

  Future<void> _init() async {
    final activeId = _currentIdirId;
    if (activeId == null) {
      _inMemoryItems.clear();
      _streamController.add(const []);
      return;
    }

    // 1. Read from persistent offline cache first
    final cached = await _loadFromCache();
    if (cached.isNotEmpty) {
      _inMemoryItems.clear();
      _inMemoryItems.addAll(cached);
      _streamController.add(List.unmodifiable(_inMemoryItems));
    }

    // 2. Refresh live data from backend
    try {
      await getContributions();
    } catch (_) {}
  }

  @override
  Stream<List<Contribution>> watchContributions() => _streamController.stream;

  @override
  Future<List<Contribution>> getContributions() async {
    final activeId = _currentIdirId;
    if (activeId == null) {
      _inMemoryItems.clear();
      _streamController.add(const []);
      return const [];
    }
    try {
      final res = await _api.get('/idirs/$activeId/contributions', queryParams: {'limit': 100});
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
      debugPrint('[RestContributionsRepository] Fetching live contributions failed (offline=${e.isOffline}): $e');
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        _inMemoryItems.clear();
        await _cache.remove(_cacheKey);
        _streamController.add(const []);
        return const [];
      }
    } catch (e) {
      debugPrint('[RestContributionsRepository] Error: $e');
    }

    // Fallback to local offline cache
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
  Future<List<Contribution>> getContributionsByMember(String memberId) async {
    final all = await getContributions();
    return all.where((c) => c.memberId == memberId).toList();
  }

  @override
  Future<Contribution?> getContributionById(String id) async {
    final all = await getContributions();
    return all.where((c) => c.id == id).firstOrNull;
  }

  @override
  Future<void> recordContribution(Contribution contribution) async {
    final clientMutationId = const Uuid().v4();

    // Optimistically update local in-memory and persistent cache
    _inMemoryItems.insert(0, contribution);
    await _saveToCache(_inMemoryItems);
    _streamController.add(List.unmodifiable(_inMemoryItems));

    // Try posting live to backend
    bool liveSuccess = false;
    try {
      // Find membership ID if available
      final members = await _membersRepository.getMembers();
      final matchedMember = members.where((m) => m.memberId == contribution.memberId || m.fullName == contribution.memberName).firstOrNull;

      await _api.post(
        '/idirs/$_currentIdirId/contributions',
        body: {
          'membershipId': matchedMember?.id ?? contribution.memberId,
          'amount': contribution.amount,
          'paymentMethod': contribution.paymentMethod.name.toUpperCase(),
          'paymentReference': contribution.notes.isNotEmpty ? contribution.notes : 'Receipt ${contribution.receiptNumber}',
          'paymentDate': contribution.date.toIso8601String(),
          'status': 'CONFIRMED',
          'clientMutationId': clientMutationId,
        },
      );
      liveSuccess = true;
    } on ApiException catch (e) {
      debugPrint('[RestContributionsRepository] Recording offline: $e');
    } catch (e) {
      debugPrint('[RestContributionsRepository] Recording failed: $e');
    }

    if (!liveSuccess) {
      // Enqueue to offline sync queue so UI indicates pending synchronization
      _ref.read(syncProvider.notifier).enqueueItem(
            title: 'Contribution: ${contribution.memberName} (ETB ${contribution.amount.toStringAsFixed(0)})',
            type: 'Contribution',
          );
    }

    await _recalculateMemberBalances(contribution.memberId);
  }

  @override
  Future<void> reverseContribution({
    required String originalId,
    required String reason,
    required String recordedByUid,
    required String recordedByName,
  }) async {
    final idx = _inMemoryItems.indexWhere((c) => c.id == originalId);
    if (idx != -1) {
      final orig = _inMemoryItems[idx];
      _inMemoryItems[idx] = orig.copyWith(
        isReversed: true,
        reversalReason: reason,
      );

      // Add reversal record
      final reversalRecord = Contribution(
        id: const Uuid().v4(),
        receiptNumber: 'REV-${orig.receiptNumber}',
        memberId: orig.memberId,
        memberName: orig.memberName,
        amount: orig.amount,
        date: DateTime.now(),
        recordedByUid: recordedByUid,
        recordedByName: recordedByName,
        paymentMethod: orig.paymentMethod,
        periodMonth: orig.periodMonth,
        periodYear: orig.periodYear,
        notes: 'REVERSAL: $reason',
        isReversal: true,
        reversalOfId: orig.id,
        reversalReason: reason,
        createdAt: DateTime.now(),
      );
      _inMemoryItems.insert(0, reversalRecord);
      await _saveToCache(_inMemoryItems);
      _streamController.add(List.unmodifiable(_inMemoryItems));

      await _recalculateMemberBalances(orig.memberId);
    }

    try {
      await _api.post(
        '/idirs/$_currentIdirId/contributions/$originalId/reverse',
        body: {'reversalReason': reason},
      );
    } catch (_) {
      _ref.read(syncProvider.notifier).enqueueItem(
            title: 'Reversal: $originalId ($reason)',
            type: 'Contribution Reversal',
          );
    }
  }

  Future<void> _recalculateMemberBalances(String memberId) async {
    final member = await _membersRepository.getMemberById(memberId);
    if (member == null) return;

    final memberHistory = await getContributionsByMember(memberId);
    final summary = _balanceCalculator.calculateSummary(
      member: member,
      memberContributions: memberHistory,
    );

    final updatedMember = member.copyWith(
      totalPaid: summary.totalPaid,
      balance: summary.balance,
      arrears: summary.arrears,
      updatedAt: DateTime.now(),
    );

    await _membersRepository.updateMember(updatedMember);
  }

  @override
  Future<String> generateNextReceiptNumber() async {
    final year = DateTime.now().year;
    final all = await getContributions();
    int highest = 0;
    for (final c in all) {
      if (c.receiptNumber.startsWith('REC-$year-')) {
        final numPart = int.tryParse(c.receiptNumber.replaceFirst('REC-$year-', ''));
        if (numPart != null && numPart > highest) {
          highest = numPart;
        }
      }
    }
    return 'REC-$year-${(highest + 1).toString().padLeft(3, '0')}';
  }

  Contribution _fromBackendJson(Map<String, dynamic> json) {
    final membership = json['membership'] as Map<String, dynamic>?;
    final user = membership?['user'] as Map<String, dynamic>?;

    final memberName = user?['fullName'] as String? ?? json['memberName'] as String? ?? 'Community Member';
    final memberId = membership?['memberNumber'] as String? ?? json['memberId'] as String? ?? 'MEM-001';
    final amount = double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0;
    final date = DateTime.tryParse(json['paymentDate']?.toString() ?? '') ?? DateTime.now();

    return Contribution(
      id: json['id'] as String? ?? const Uuid().v4(),
      receiptNumber: json['receiptNumber'] as String? ?? 'REC-${date.year}-001',
      memberId: memberId,
      memberName: memberName,
      amount: amount,
      date: date,
      recordedByUid: json['recordedById'] as String? ?? 'system',
      recordedByName: 'Officer',
      paymentMethod: PaymentMethodX.fromString(json['paymentMethod'] as String?),
      periodMonth: date.month,
      periodYear: date.year,
      notes: json['paymentReference'] as String? ?? '',
      isReversal: json['isReversal'] == true,
      reversalOfId: json['reversalOfId'] as String?,
      reversalReason: json['reversalReason'] as String?,
      isReversed: json['isReversed'] == true || json['status'] == 'REVERSED',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? date,
    );
  }

  Future<List<Contribution>> _loadFromCache() async {
    final cached = await _cache.read(_cacheKey);
    if (cached is List<dynamic>) {
      return cached.map((e) => Contribution.fromMap((e as Map<String, dynamic>)['id'] as String? ?? '', e)).toList();
    }
    return [];
  }

  Future<void> _saveToCache(List<Contribution> list) async {
    final jsonList = list.map((c) {
      final map = c.toMap();
      map['id'] = c.id;
      return map;
    }).toList();
    await _cache.save(_cacheKey, jsonList);
  }
}
