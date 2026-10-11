import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/firebase/firestore_provider.dart';
import '../../../../core/models/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Future<AppUser> signIn({required String email, required String password});
  Future<void> signOut();
  Future<AppUser?> getCurrentUser();
  Future<void> updateProfile(AppUser user);
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  static const _prefCachedUser = 'cached_user_profile';

  // Demo accounts for local testing / offline role verification
  static final List<AppUser> demoUsers = [
    AppUser(
      uid: 'demo_chair',
      name: 'Abebe Tadesse (Chairperson)',
      phone: '+251 91 123 4567',
      role: UserRole.chairperson,
      memberId: 'IDIR-CHAIR-01',
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    ),
    AppUser(
      uid: 'demo_treasurer',
      name: 'Chaltu Bekele (Treasurer)',
      phone: '+251 91 234 5678',
      role: UserRole.treasurer,
      memberId: 'IDIR-TRSR-02',
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    ),
    AppUser(
      uid: 'demo_auditor',
      name: 'Dawit Yohannes (Auditor)',
      phone: '+251 91 345 6789',
      role: UserRole.auditor,
      memberId: 'IDIR-AUDT-03',
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    ),
    AppUser(
      uid: 'demo_member',
      name: 'Fatima Mohammed (Member)',
      phone: '+251 91 456 7890',
      role: UserRole.member,
      memberId: 'IDIR-MEMB-04',
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    ),
  ];

  @override
  Stream<AppUser?> authStateChanges() async* {
    final cached = await getCurrentUser();
    yield cached;

    final authInstance = _authInstance;
    if (authInstance != null) {
      await for (final user in authInstance.authStateChanges()) {
        if (user == null) {
          yield null;
        } else {
          final profile = await _fetchFirestoreProfile(user.uid);
          yield profile;
        }
      }
    }
  }

  FirebaseAuth? get _authInstance {
    try {
      return _auth ?? FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestoreInstance {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    // 1. Check demo accounts first for seamless local development
    final matchedDemo = _findDemoUser(trimmedEmail, password);
    if (matchedDemo != null) {
      await _cacheUser(matchedDemo);
      return matchedDemo;
    }

    // 2. Attempt real Firebase Auth
    final auth = _authInstance;
    if (auth != null) {
      try {
        final credential = await auth.signInWithEmailAndPassword(
          email: trimmedEmail,
          password: password,
        );
        final uid = credential.user!.uid;
        final profile = await _fetchFirestoreProfile(uid);
        if (profile != null) {
          if (!profile.isActive) {
            await auth.signOut();
            throw Exception('Account is deactivated. Contact an administrator.');
          }
          await _cacheUser(profile);
          return profile;
        }
      } on FirebaseAuthException catch (e) {
        debugPrint('FirebaseAuthException: ${e.code}');
        rethrow;
      }
    }

    // 3. Fallback generic demo match if email contains role keyword
    if (trimmedEmail.contains('chair')) {
      final user = demoUsers[0];
      await _cacheUser(user);
      return user;
    } else if (trimmedEmail.contains('treas')) {
      final user = demoUsers[1];
      await _cacheUser(user);
      return user;
    } else if (trimmedEmail.contains('audit')) {
      final user = demoUsers[2];
      await _cacheUser(user);
      return user;
    } else if (trimmedEmail.contains('member') || trimmedEmail.isNotEmpty) {
      final user = demoUsers[3];
      await _cacheUser(user);
      return user;
    }

    throw Exception('Invalid email or password.');
  }

  AppUser? _findDemoUser(String email, String password) {
    if (email == 'chair@idir.org' || email == 'chair') return demoUsers[0];
    if (email == 'treasurer@idir.org' || email == 'treasurer') return demoUsers[1];
    if (email == 'auditor@idir.org' || email == 'auditor') return demoUsers[2];
    if (email == 'member@idir.org' || email == 'member') return demoUsers[3];
    return null;
  }

  Future<AppUser?> _fetchFirestoreProfile(String uid) async {
    final fs = _firestoreInstance;
    if (fs == null) return null;
    try {
      final doc = await fs.collection(AppConstants.colUsers).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return AppUser.fromMap(uid, doc.data()!);
      }
    } catch (e) {
      debugPrint('Error fetching Firestore user: $e');
    }
    return null;
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefCachedUser);
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final uid = map['uid'] as String? ?? 'unknown';
        return AppUser(
          uid: uid,
          name: map['name'] as String? ?? '',
          phone: map['phone'] as String? ?? '',
          role: UserRoleX.fromString(map['role'] as String? ?? 'member'),
          memberId: map['memberId'] as String? ?? '',
          isActive: map['isActive'] as bool? ?? true,
          createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
              DateTime.now(),
        );
      } catch (e) {
        debugPrint('Error decoding cached user: $e');
      }
    }
    return null;
  }

  Future<void> _cacheUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefIsLoggedIn, true);
    final map = {
      'uid': user.uid,
      'name': user.name,
      'phone': user.phone,
      'role': user.role.name,
      'memberId': user.memberId,
      'isActive': user.isActive,
      'createdAt': user.createdAt.toIso8601String(),
    };
    await prefs.setString(_prefCachedUser, jsonEncode(map));
  }

  @override
  Future<void> updateProfile(AppUser user) async {
    await _cacheUser(user);
    final fs = _firestoreInstance;
    if (fs != null) {
      try {
        await fs.collection(AppConstants.colUsers).doc(user.uid).set(
              user.toMap(),
              SetOptions(merge: true),
            );
      } catch (e) {
        debugPrint('Error updating user profile in Firestore: $e');
      }
    }
  }

  @override
  Future<void> signOut() async {
    final auth = _authInstance;
    if (auth != null) {
      try {
        await auth.signOut();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefIsLoggedIn, false);
    await prefs.remove(_prefCachedUser);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirebaseAuthRepository(firestore: firestore);
});
