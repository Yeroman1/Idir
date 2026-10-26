import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../../../../core/storage/offline_cache_service.dart';
import '../domain/models/member.dart';
import 'rest_members_repository.dart';

abstract class MembersRepository {
  Stream<List<Member>> watchMembers();
  Future<List<Member>> getMembers();
  Future<Member?> getMemberById(String id);
  Future<void> addMember(Member member);
  Future<void> updateMember(Member member);
  Future<void> deleteMember(String id);
  Future<String> generateNextMemberId();
}

class FirestoreMembersRepository implements MembersRepository {
  FirestoreMembersRepository({FirebaseFirestore? firestore})
      : _firestore = firestore {
    _initLocalDemoSeed();
  }

  final FirebaseFirestore? _firestore;

  // Local fallback cache for offline/demo operation
  final List<Member> _localCache = [];
  final _streamController = StreamController<List<Member>>.broadcast();

  FirebaseFirestore? get _fs {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  void _initLocalDemoSeed() {
    // No mock demo data in production real application
  }

  /// Isolated test helper strictly for offline unit tests
  void seedForTest() {
    final now = DateTime.now();
    _localCache.clear();
    _localCache.addAll([
      Member(
        id: 'mem_1',
        memberId: 'MEM-001',
        fullName: 'Abebe Tadesse',
        phone: '+251 91 123 4567',
        registeredAt: now.subtract(const Duration(days: 365)),
        monthlyDues: 50.0,
        status: MemberStatus.active,
        dependents: const [
          Dependent(id: 'dep_1', name: 'Tigist Abebe', relationship: 'Spouse'),
          Dependent(id: 'dep_2', name: 'Dawit Abebe', relationship: 'Child'),
        ],
        createdAt: now.subtract(const Duration(days: 365)),
        updatedAt: now.subtract(const Duration(days: 365)),
      ),
      Member(
        id: 'mem_2',
        memberId: 'MEM-002',
        fullName: 'Almaz Ayana',
        phone: '+251 91 234 5678',
        registeredAt: now.subtract(const Duration(days: 300)),
        monthlyDues: 50.0,
        status: MemberStatus.active,
        createdAt: now.subtract(const Duration(days: 300)),
        updatedAt: now.subtract(const Duration(days: 300)),
      ),
      Member(
        id: 'mem_3',
        memberId: 'MEM-003',
        fullName: 'Haile Gebrselassie',
        phone: '+251 91 345 6789',
        registeredAt: now.subtract(const Duration(days: 200)),
        monthlyDues: 50.0,
        status: MemberStatus.active,
        createdAt: now.subtract(const Duration(days: 200)),
        updatedAt: now.subtract(const Duration(days: 200)),
      ),
      Member(
        id: 'mem_4',
        memberId: 'MEM-004',
        fullName: 'Derartu Tulu',
        phone: '+251 91 456 7890',
        registeredAt: now.subtract(const Duration(days: 100)),
        monthlyDues: 50.0,
        status: MemberStatus.suspended,
        createdAt: now.subtract(const Duration(days: 100)),
        updatedAt: now.subtract(const Duration(days: 100)),
      ),
      Member(
        id: 'mem_5',
        memberId: 'MEM-005',
        fullName: 'Tirunesh Dibaba',
        phone: '+251 91 567 8901',
        registeredAt: now.subtract(const Duration(days: 50)),
        monthlyDues: 50.0,
        status: MemberStatus.active,
        createdAt: now.subtract(const Duration(days: 50)),
        updatedAt: now.subtract(const Duration(days: 50)),
      ),
    ]);
  }

  @override
  Stream<List<Member>> watchMembers() async* {
    final fs = _fs;
    if (fs != null) {
      try {
        final stream = fs
            .collection(AppConstants.colMembers)
            .orderBy('memberId')
            .snapshots();

        await for (final snapshot in stream) {
          if (snapshot.docs.isNotEmpty) {
            final members = snapshot.docs
                .map((d) => Member.fromMap(d.id, d.data()))
                .toList();
            yield members;
            continue;
          }
          // If Firestore collection is empty, emit local cache
          yield List.unmodifiable(_localCache);
        }
        return;
      } catch (e) {
        debugPrint('Firestore watchMembers fallback to local: $e');
      }
    }

    // Local / Offline stream
    yield List.unmodifiable(_localCache);
    yield* _streamController.stream;
  }

  @override
  Future<List<Member>> getMembers() async {
    final fs = _fs;
    if (fs != null) {
      try {
        final snapshot = await fs
            .collection(AppConstants.colMembers)
            .orderBy('memberId')
            .get();
        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs
              .map((d) => Member.fromMap(d.id, d.data()))
              .toList();
        }
      } catch (e) {
        debugPrint('Firestore getMembers fallback: $e');
      }
    }
    return List.unmodifiable(_localCache);
  }

  @override
  Future<Member?> getMemberById(String id) async {
    final fs = _fs;
    if (fs != null) {
      try {
        final doc = await fs.collection(AppConstants.colMembers).doc(id).get();
        if (doc.exists && doc.data() != null) {
          return Member.fromMap(doc.id, doc.data()!);
        }
      } catch (e) {
        debugPrint('Firestore getMemberById fallback: $e');
      }
    }
    try {
      return _localCache.firstWhere((m) => m.id == id || m.memberId == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addMember(Member member) async {
    final fs = _fs;
    if (fs != null) {
      try {
        await fs
            .collection(AppConstants.colMembers)
            .doc(member.id)
            .set(member.toMap());
      } catch (e) {
        debugPrint('Firestore addMember fallback: $e');
      }
    }

    _localCache.removeWhere((m) => m.id == member.id);
    _localCache.add(member);
    _localCache.sort((a, b) => a.memberId.compareTo(b.memberId));
    _streamController.add(List.unmodifiable(_localCache));
  }

  @override
  Future<void> updateMember(Member member) async {
    final fs = _fs;
    if (fs != null) {
      try {
        await fs
            .collection(AppConstants.colMembers)
            .doc(member.id)
            .update(member.toMap());
      } catch (e) {
        debugPrint('Firestore updateMember fallback: $e');
      }
    }

    final index = _localCache.indexWhere((m) => m.id == member.id);
    if (index != -1) {
      _localCache[index] = member;
    } else {
      _localCache.add(member);
    }
    _streamController.add(List.unmodifiable(_localCache));
  }

  @override
  Future<void> deleteMember(String id) async {
    final fs = _fs;
    if (fs != null) {
      try {
        await fs.collection(AppConstants.colMembers).doc(id).delete();
      } catch (e) {
        debugPrint('Firestore deleteMember fallback: $e');
      }
    }

    _localCache.removeWhere((m) => m.id == id);
    _streamController.add(List.unmodifiable(_localCache));
  }

  @override
  Future<String> generateNextMemberId() async {
    final members = await getMembers();
    int highestNum = 0;
    for (final m in members) {
      final match = RegExp(r'\d+').firstMatch(m.memberId);
      if (match != null) {
        final n = int.tryParse(match.group(0) ?? '') ?? 0;
        if (n > highestNum) highestNum = n;
      }
    }
    final nextNum = highestNum + 1;
    return 'MEM-${nextNum.toString().padLeft(3, '0')}';
  }
}

final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  final activeIdirId = ref.watch(activeIdirIdProvider);
  return RestMembersRepository(
    apiClient: apiClient,
    cacheService: cache,
    ref: ref,
    idirId: activeIdirId,
  );
});
