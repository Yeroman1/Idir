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
import '../domain/models/expense.dart';
import 'expenses_repository.dart';

class RestExpensesRepository implements ExpensesRepository {
  RestExpensesRepository({
    required ApiClient apiClient,
    required OfflineCacheService cacheService,
    required Ref ref,
    String? idirId,
  })  : _api = apiClient,
        _cache = cacheService,
        _ref = ref,
        _idirId = idirId {
    _streamController = StreamController<List<Expense>>.broadcast(
      onListen: () {
        _streamController.add(List.unmodifiable(_inMemoryItems));
      },
    );

    _ref.read(syncProvider.notifier).registerSyncCallback(getExpenses);
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

  String get _cacheKey => 'cache_expenses_${_currentIdirId ?? "none"}';
  final List<Expense> _inMemoryItems = [];
  late final StreamController<List<Expense>> _streamController;

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
      await getExpenses();
    } catch (_) {}
  }

  @override
  Stream<List<Expense>> watchExpenses() => _streamController.stream;

  @override
  Future<List<Expense>> getExpenses() async {
    final activeId = _currentIdirId;
    if (activeId == null) {
      _inMemoryItems.clear();
      _streamController.add(const []);
      return const [];
    }
    try {
      final res = await _api.get('/idirs/$activeId/expenses', queryParams: {'limit': 100});
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
      debugPrint('[RestExpensesRepository] Live fetch failed (offline=${e.isOffline}): $e');
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        _inMemoryItems.clear();
        await _cache.remove(_cacheKey);
        _streamController.add(const []);
        return const [];
      }
    } catch (e) {
      debugPrint('[RestExpensesRepository] Error: $e');
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
  Future<Expense?> getExpenseById(String id) async {
    final all = await getExpenses();
    return all.where((e) => e.id == id).firstOrNull;
  }

  @override
  Future<void> recordExpense(Expense expense) async {
    _inMemoryItems.insert(0, expense);
    await _saveToCache(_inMemoryItems);
    _streamController.add(List.unmodifiable(_inMemoryItems));

    try {
      await _api.post(
        '/idirs/$_currentIdirId/expenses',
        body: {
          'category': expense.category.name.toUpperCase(),
          'amount': expense.amount,
          'description': expense.description,
          'voucherNumber': expense.voucherNumber,
        },
      );
    } catch (_) {
      _ref.read(syncProvider.notifier).enqueueItem(
            title: 'Expense: ${expense.description} (ETB ${expense.amount.toStringAsFixed(0)})',
            type: 'Expense Voucher',
          );
    }
  }

  @override
  Future<void> reverseExpense({
    required String originalId,
    required String reason,
    required String recordedByUid,
    required String recordedByName,
  }) async {
    final idx = _inMemoryItems.indexWhere((e) => e.id == originalId);
    if (idx != -1) {
      final orig = _inMemoryItems[idx];
      _inMemoryItems[idx] = orig.copyWith(
        isReversed: true,
        reversalReason: reason,
      );

      final reversalRecord = Expense(
        id: const Uuid().v4(),
        voucherNumber: 'REV-${orig.voucherNumber}',
        category: orig.category,
        amount: orig.amount,
        description: 'REVERSAL: $reason',
        isReversal: true,
        reversalOfId: orig.id,
        reversalReason: reason,
        recordedByUid: recordedByUid,
        recordedByName: recordedByName,
        createdAt: DateTime.now(),
      );
      _inMemoryItems.insert(0, reversalRecord);
      await _saveToCache(_inMemoryItems);
      _streamController.add(List.unmodifiable(_inMemoryItems));
    }

    try {
      await _api.post(
        '/idirs/$_currentIdirId/expenses/$originalId/reverse',
        body: {'reversalReason': reason},
      );
    } catch (_) {
      _ref.read(syncProvider.notifier).enqueueItem(
            title: 'Reverse Expense: $originalId',
            type: 'Expense Reversal',
          );
    }
  }

  @override
  Future<String> generateNextVoucherNumber() async {
    final year = DateTime.now().year;
    final all = await getExpenses();
    int highest = 0;
    for (final e in all) {
      if (e.voucherNumber.startsWith('EXP-$year-')) {
        final numPart = int.tryParse(e.voucherNumber.replaceFirst('EXP-$year-', ''));
        if (numPart != null && numPart > highest) {
          highest = numPart;
        }
      }
    }
    return 'EXP-$year-${(highest + 1).toString().padLeft(3, '0')}';
  }

  Expense _fromBackendJson(Map<String, dynamic> json) {
    final categoryStr = json['category'] as String?;
    final amount = double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0;
    final date = DateTime.tryParse(json['expenseDate']?.toString() ?? '') ?? DateTime.now();

    return Expense(
      id: json['id'] as String? ?? const Uuid().v4(),
      voucherNumber: json['voucherNumber'] as String? ?? 'EXP-${date.year}-001',
      category: ExpenseCategoryX.fromString(categoryStr),
      amount: amount,
      description: json['description'] as String? ?? '',
      recordedByUid: json['recordedById'] as String? ?? 'officer',
      recordedByName: 'Treasurer',
      isReversal: json['isReversal'] == true,
      reversalOfId: json['reversalOfId'] as String?,
      reversalReason: json['reversalReason'] as String?,
      isReversed: json['isReversed'] == true,
      createdAt: date,
    );
  }

  Future<List<Expense>> _loadFromCache() async {
    final cached = await _cache.read(_cacheKey);
    if (cached is List<dynamic>) {
      return cached.map((e) => Expense.fromMap((e as Map<String, dynamic>)['id'] as String? ?? '', e)).toList();
    }
    return [];
  }

  Future<void> _saveToCache(List<Expense> list) async {
    final jsonList = list.map((e) {
      final map = e.toMap();
      map['id'] = e.id;
      return map;
    }).toList();
    await _cache.save(_cacheKey, jsonList);
  }
}
