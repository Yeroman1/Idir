import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/sync_status_provider.dart';
import '../../../../core/storage/offline_cache_service.dart';
import '../domain/models/member.dart';
import 'members_repository.dart';

class RestMembersRepository implements MembersRepository {
  RestMembersRepository({
    required ApiClient apiClient,
    required OfflineCacheService cacheService,
    required Ref ref,
    String idirId = AppConstants.defaultIdirId,
  })  : _api = apiClient,
        _cache = cacheService,
        _ref = ref,
        _idirId = idirId {
    _streamController = StreamController<List<Member>>.broadcast(
      onListen: () {
        _streamController.add(List.unmodifiable(_inMemoryItems));
      },
    );

    // Register with sync manager to refresh when online/reconnecting
    _ref.read(syncProvider.notifier).registerSyncCallback(getMembers);
    _init();
  }

  final ApiClient _api;
  final OfflineCacheService _cache;
  final Ref _ref;
  final String _idirId;

  static const _cacheKey = 'cache_members';
  final List<Member> _inMemoryItems = [];
  late final StreamController<List<Member>> _streamController;

  Future<void> _init() async {
    final cached = await _loadFromCache();
    if (cached.isNotEmpty) {
      _inMemoryItems.clear();
      _inMemoryItems.addAll(cached);
      _streamController.add(List.unmodifiable(_inMemoryItems));
    }

    try {
      await getMembers();
    } catch (_) {}
  }

  @override
  Stream<List<Member>> watchMembers() => _streamController.stream;

  @override
  Future<List<Member>> getMembers() async {
    try {
      final res = await _api.get('/idirs/$_idirId/members', queryParams: {'limit': 100});
      List<dynamic> rawItems = [];
      if (res is Map<String, dynamic> && res.containsKey('items')) {
        rawItems = res['items'] as List<dynamic>? ?? [];
      } else if (res is List<dynamic>) {
        rawItems = res;
      }

      final parsed = rawItems.map((e) => _fromBackendJson(e as Map<String, dynamic>)).toList();

      if (parsed.isNotEmpty) {
        _inMemoryItems.clear();
        _inMemoryItems.addAll(parsed);
        await _saveToCache(_inMemoryItems);
        _streamController.add(List.unmodifiable(_inMemoryItems));
        return List.unmodifiable(_inMemoryItems);
      }
    } on ApiException catch (e) {
      debugPrint('[RestMembersRepository] Fetching live members failed (offline=${e.isOffline}): $e');
    } catch (e) {
      debugPrint('[RestMembersRepository] Error: $e');
    }

    // Fallback to offline cached data
    final cached = await _loadFromCache();
    if (cached.isNotEmpty) {
      _inMemoryItems.clear();
      _inMemoryItems.addAll(cached);
      _streamController.add(List.unmodifiable(_inMemoryItems));
      return List.unmodifiable(_inMemoryItems);
    }

    if (_inMemoryItems.isEmpty) {
      final seed = _generateDemoSeed();
      _inMemoryItems.addAll(seed);
      await _saveToCache(_inMemoryItems);
      _streamController.add(List.unmodifiable(_inMemoryItems));
    }

    return List.unmodifiable(_inMemoryItems);
  }

  @override
  Future<Member?> getMemberById(String id) async {
    final all = await getMembers();
    return all.where((m) => m.id == id || m.memberId == id).firstOrNull;
  }

  @override
  Future<void> addMember(Member member) async {
    _inMemoryItems.add(member);
    await _saveToCache(_inMemoryItems);
    _streamController.add(List.unmodifiable(_inMemoryItems));

    try {
      await _api.post(
        '/idirs/$_idirId/members',
        body: {
          'memberNumber': member.memberId,
          'phoneNumber': member.phone,
          'role': 'MEMBER',
        },
      );
    } catch (_) {
      _ref.read(syncProvider.notifier).enqueueItem(
            title: 'New Member: ${member.fullName} (${member.memberId})',
            type: 'Member Registration',
          );
    }
  }

  @override
  Future<void> updateMember(Member member) async {
    final idx = _inMemoryItems.indexWhere((m) => m.id == member.id);
    if (idx != -1) {
      _inMemoryItems[idx] = member;
      await _saveToCache(_inMemoryItems);
      _streamController.add(List.unmodifiable(_inMemoryItems));
    }

    try {
      await _api.put(
        '/idirs/$_idirId/members/${member.id}',
        body: {
          'memberNumber': member.memberId,
          'status': member.status.name.toUpperCase(),
        },
      );
    } catch (_) {
      _ref.read(syncProvider.notifier).enqueueItem(
            title: 'Update Member: ${member.fullName}',
            type: 'Member Update',
          );
    }
  }

  @override
  Future<void> deleteMember(String id) async {
    _inMemoryItems.removeWhere((m) => m.id == id);
    await _saveToCache(_inMemoryItems);
    _streamController.add(List.unmodifiable(_inMemoryItems));

    try {
      await _api.delete('/idirs/$_idirId/members/$id');
    } catch (_) {}
  }

  @override
  Future<String> generateNextMemberId() async {
    final all = await getMembers();
    int highest = 0;
    for (final m in all) {
      final match = RegExp(r'\d+').firstMatch(m.memberId);
      if (match != null) {
        final n = int.tryParse(match.group(0) ?? '') ?? 0;
        if (n > highest) highest = n;
      }
    }
    return 'BM-${(highest + 1).toString().padLeft(3, '0')}';
  }

  Member _fromBackendJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final fullName = user?['fullName'] as String? ?? json['fullName'] as String? ?? 'Member';
    final phone = user?['phoneNumber'] as String? ?? json['phone'] as String? ?? '';
    final memberId = json['memberNumber'] as String? ?? json['memberId'] as String? ?? 'BM-001';
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now();

    final statusStr = (json['status'] as String? ?? '').toUpperCase();
    final status = switch (statusStr) {
      'SUSPENDED' => MemberStatus.suspended,
      'DECEASED' => MemberStatus.deceased,
      _ => MemberStatus.active,
    };

    return Member(
      id: json['id'] as String? ?? const Uuid().v4(),
      memberId: memberId,
      fullName: fullName,
      phone: phone,
      registeredAt: createdAt,
      monthlyDues: 200.0,
      status: status,
      emergencyContact: const EmergencyContact(name: 'Contact', phone: '', relationship: 'Family'),
      dependents: const [],
      totalPaid: 600.0,
      balance: 0.0,
      arrears: 0.0,
      notes: 'Registered in Bole Medhanealem Idir',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  Future<List<Member>> _loadFromCache() async {
    final cached = await _cache.read(_cacheKey);
    if (cached is List<dynamic>) {
      return cached.map((e) => Member.fromMap((e as Map<String, dynamic>)['id'] as String? ?? '', e)).toList();
    }
    return [];
  }

  Future<void> _saveToCache(List<Member> list) async {
    final jsonList = list.map((m) {
      final map = m.toMap();
      map['id'] = m.id;
      return map;
    }).toList();
    await _cache.save(_cacheKey, jsonList);
  }

  List<Member> _generateDemoSeed() {
    return [
      Member(
        id: 'mem_1',
        memberId: 'BM-001',
        fullName: 'Abebe Tadesse Kebede',
        phone: '+251 91 111 1111',
        registeredAt: DateTime(2023, 1, 15),
        monthlyDues: 200.0,
        status: MemberStatus.active,
        emergencyContact: const EmergencyContact(
          name: 'Almaz Tadesse',
          phone: '+251 91 111 2233',
          relationship: 'Spouse',
        ),
        dependents: const [
          Dependent(id: 'd1', name: 'Yared Abebe', relationship: 'Son'),
        ],
        totalPaid: 2400.0,
        balance: 200.0,
        arrears: 0.0,
        notes: 'Chairperson',
        createdAt: DateTime(2023, 1, 15),
        updatedAt: DateTime(2023, 1, 15),
      ),
      Member(
        id: 'mem_2',
        memberId: 'BM-002',
        fullName: 'Chaltu Bekele Gemeda',
        phone: '+251 91 122 2222',
        registeredAt: DateTime(2023, 3, 10),
        monthlyDues: 200.0,
        status: MemberStatus.active,
        emergencyContact: const EmergencyContact(
          name: 'Bekele Gemechu',
          phone: '+251 91 222 3344',
          relationship: 'Father',
        ),
        dependents: const [],
        totalPaid: 2400.0,
        balance: 0.0,
        arrears: 0.0,
        notes: 'Treasurer',
        createdAt: DateTime(2023, 3, 10),
        updatedAt: DateTime(2023, 3, 10),
      ),
    ];
  }
}
