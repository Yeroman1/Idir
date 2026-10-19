import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
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
    _localCache.addAll([
      Member(
        id: 'mem_1',
        memberId: 'MEM-001',
        fullName: 'Abebe Tadesse',
        phone: '+251 91 123 4567',
        registeredAt: DateTime(2023, 1, 15),
        monthlyDues: 50.0,
        status: MemberStatus.active,
        emergencyContact: const EmergencyContact(
          name: 'Almaz Tadesse',
          phone: '+251 91 111 2233',
          relationship: 'Spouse',
        ),
        dependents: const [
          Dependent(id: 'd1', name: 'Yared Abebe', relationship: 'Son'),
          Dependent(id: 'd2', name: 'Sara Abebe', relationship: 'Daughter'),
        ],
        totalPaid: 650.0,
        balance: 150.0,
        arrears: 0.0,
        notes: 'Founding member, prompt payer',
        createdAt: DateTime(2023, 1, 15),
        updatedAt: DateTime(2023, 1, 15),
      ),
      Member(
        id: 'mem_2',
        memberId: 'MEM-002',
        fullName: 'Chaltu Bekele',
        phone: '+251 91 234 5678',
        registeredAt: DateTime(2023, 3, 10),
        monthlyDues: 50.0,
        status: MemberStatus.active,
        emergencyContact: const EmergencyContact(
          name: 'Bekele Gemechu',
          phone: '+251 91 222 3344',
          relationship: 'Father',
        ),
        dependents: const [
          Dependent(id: 'd3', name: 'Sena Bekele', relationship: 'Sister'),
        ],
        totalPaid: 500.0,
        balance: 0.0,
        arrears: 0.0,
        notes: 'Treasurer role assigned in users collection',
        createdAt: DateTime(2023, 3, 10),
        updatedAt: DateTime(2023, 3, 10),
      ),
      Member(
        id: 'mem_3',
        memberId: 'MEM-003',
        fullName: 'Dawit Yohannes',
        phone: '+251 91 345 6789',
        registeredAt: DateTime(2023, 5, 20),
        monthlyDues: 50.0,
        status: MemberStatus.active,
        emergencyContact: const EmergencyContact(
          name: 'Helen Dawit',
          phone: '+251 91 333 4455',
          relationship: 'Spouse',
        ),
        dependents: const [
          Dependent(id: 'd4', name: 'Natnael Dawit', relationship: 'Son'),
        ],
        totalPaid: 400.0,
        balance: -100.0,
        arrears: 100.0,
        notes: 'Pending payment for past 2 months',
        createdAt: DateTime(2023, 5, 20),
        updatedAt: DateTime(2023, 5, 20),
      ),
      Member(
        id: 'mem_4',
        memberId: 'MEM-004',
        fullName: 'Fatima Mohammed',
        phone: '+251 91 456 7890',
        registeredAt: DateTime(2023, 6, 1),
        monthlyDues: 50.0,
        status: MemberStatus.suspended,
        emergencyContact: const EmergencyContact(
          name: 'Ahmed Ali',
          phone: '+251 91 444 5566',
          relationship: 'Brother',
        ),
        dependents: const [],
        totalPaid: 250.0,
        balance: -150.0,
        arrears: 150.0,
        notes: 'Temporary relocation outside district',
        createdAt: DateTime(2023, 6, 1),
        updatedAt: DateTime(2023, 6, 1),
      ),
      Member(
        id: 'mem_5',
        memberId: 'MEM-005',
        fullName: 'Haile Gebrselassie',
        phone: '+251 91 567 8901',
        registeredAt: DateTime(2023, 8, 12),
        monthlyDues: 50.0,
        status: MemberStatus.active,
        emergencyContact: const EmergencyContact(
          name: 'Aster Haile',
          phone: '+251 91 555 6677',
          relationship: 'Spouse',
        ),
        dependents: const [
          Dependent(id: 'd5', name: 'Eden Haile', relationship: 'Daughter'),
          Dependent(id: 'd6', name: 'Meklit Haile', relationship: 'Daughter'),
        ],
        totalPaid: 700.0,
        balance: 200.0,
        arrears: 0.0,
        notes: 'Advance dues paid for 4 months',
        createdAt: DateTime(2023, 8, 12),
        updatedAt: DateTime(2023, 8, 12),
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
  return RestMembersRepository(
    apiClient: apiClient,
    cacheService: cache,
    ref: ref,
  );
});
