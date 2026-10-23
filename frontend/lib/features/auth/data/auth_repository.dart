import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/offline_cache_service.dart';
import 'fayda_service.dart';
import 'rest_auth_repository.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Future<FaydaOtpResponse> requestFaydaOtp(String faydaId);
  Future<FaydaCitizenProfile> verifyFaydaCitizenOtp({
    required String faydaId,
    required String otp,
    required String txnId,
  });
  Future<AppUser> registerWithPassword({
    required String fullName,
    required String phoneNumber,
    required String faydaId,
    required String password,
  });
  Future<AppUser> signInWithPassword({
    required String identifier,
    required String password,
  });
  Future<AppUser> verifyFaydaOtp({
    required String faydaId,
    required String otp,
    required String txnId,
  });
  Future<AppUser> signIn({required String email, required String password});
  Future<void> signOut();
  Future<AppUser?> getCurrentUser();
  Future<void> updateProfile(AppUser user);
  Future<AppUser> setSessionFromAuthResponse(Map<String, dynamic> responseData);
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FaydaService? faydaService,
  })  : _auth = auth,
        _firestore = firestore,
        _faydaService = faydaService ?? FaydaService();

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final FaydaService _faydaService;

  static const _prefCachedUser = 'cached_user_profile';

  // Demo accounts linked with official Ethiopian National ID (Fayda) FINs
  static final List<AppUser> demoUsers = [
    AppUser(
      uid: 'demo_chair',
      name: 'Abebe Tadesse Kebede',
      phone: '+251911111111',
      role: UserRole.chairperson,
      memberId: 'IDIR-CHAIR-01',
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
      faydaId: '100020003001',
    ),
    AppUser(
      uid: 'demo_treasurer',
      name: 'Chaltu Bekele Gemeda',
      phone: '+251911222222',
      role: UserRole.treasurer,
      memberId: 'IDIR-TRSR-02',
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
      faydaId: '100020003002',
    ),
    AppUser(
      uid: 'demo_auditor',
      name: 'Dawit Adugna Hailu',
      phone: '+251911333333',
      role: UserRole.auditor,
      memberId: 'IDIR-AUDT-03',
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
      faydaId: '100020003003',
    ),
    AppUser(
      uid: 'demo_member',
      name: 'Fatima Mohammed Ali',
      phone: '+251911444444',
      role: UserRole.member,
      memberId: 'IDIR-MEMB-04',
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
      faydaId: '100020003004',
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
  Future<FaydaOtpResponse> requestFaydaOtp(String faydaId) async {
    return _faydaService.requestOtp(faydaId);
  }

  @override
  Future<AppUser> verifyFaydaOtp({
    required String faydaId,
    required String otp,
    required String txnId,
  }) async {
    // 1. Verify OTP with the Fayda API
    final citizen = await _faydaService.verifyOtp(
      faydaInput: faydaId,
      otp: otp,
      txnId: txnId,
    );

    final cleanFin = FaydaService.normalizeFin(citizen.fin);

    // 2. Check for registered demo role profiles
    final matchedDemo = _findDemoUserByFaydaId(cleanFin);
    if (matchedDemo != null) {
      await _cacheUser(matchedDemo);
      return matchedDemo;
    }

    // 3. Check Firestore for existing user account tied to this Fayda ID
    final fs = _firestoreInstance;
    if (fs != null) {
      try {
        // Query by faydaId field
        final querySnap = await fs
            .collection(AppConstants.colUsers)
            .where('faydaId', isEqualTo: cleanFin)
            .limit(1)
            .get();

        if (querySnap.docs.isNotEmpty) {
          final doc = querySnap.docs.first;
          final user = AppUser.fromMap(doc.id, doc.data());
          if (!user.isActive) {
            throw Exception('This Fayda account is deactivated. Contact an Idir officer.');
          }
          await _cacheUser(user);
          return user;
        }

        // Check if a direct doc with ID fayda_<fin> exists
        final directDoc = await fs.collection(AppConstants.colUsers).doc('fayda_$cleanFin').get();
        if (directDoc.exists && directDoc.data() != null) {
          final user = AppUser.fromMap(directDoc.id, directDoc.data()!);
          if (!user.isActive) {
            throw Exception('This Fayda account is deactivated. Contact an Idir officer.');
          }
          await _cacheUser(user);
          return user;
        }

        // 4. Automatic registration for new Ethiopian National ID citizen
        final newMemberId = 'IDIR-F-${cleanFin.length >= 4 ? cleanFin.substring(cleanFin.length - 4) : cleanFin}';
        final newUser = AppUser(
          uid: 'fayda_$cleanFin',
          name: citizen.fullName,
          phone: citizen.phone,
          role: UserRole.member,
          memberId: newMemberId,
          isActive: true,
          createdAt: DateTime.now(),
          faydaId: cleanFin,
        );

        await fs.collection(AppConstants.colUsers).doc(newUser.uid).set(
              newUser.toMap(),
              SetOptions(merge: true),
            );

        await _cacheUser(newUser);
        return newUser;
      } catch (e) {
        debugPrint('Firestore lookup/registration notice: $e');
        if (e is Exception && e.toString().contains('deactivated')) {
          rethrow;
        }
      }
    }

    // 5. Fallback local profile if offline or without Firebase connection
    final fallbackUser = AppUser(
      uid: 'fayda_$cleanFin',
      name: citizen.fullName,
      phone: citizen.phone,
      role: UserRole.member,
      memberId: 'IDIR-F-${cleanFin.length >= 4 ? cleanFin.substring(cleanFin.length - 4) : cleanFin}',
      isActive: true,
      createdAt: DateTime.now(),
      faydaId: cleanFin,
    );
    await _cacheUser(fallbackUser);
    return fallbackUser;
  }

  AppUser? _findDemoUserByFaydaId(String fin) {
    for (final demo in demoUsers) {
      if (demo.faydaId == fin) {
        return demo;
      }
    }
    return null;
  }

  @override
  Future<FaydaCitizenProfile> verifyFaydaCitizenOtp({
    required String faydaId,
    required String otp,
    required String txnId,
  }) async {
    return _faydaService.verifyOtp(
      faydaInput: faydaId,
      otp: otp,
      txnId: txnId,
    );
  }

  @override
  Future<AppUser> registerWithPassword({
    required String fullName,
    required String phoneNumber,
    required String faydaId,
    required String password,
  }) async {
    final cleanFin = FaydaService.normalizeFin(faydaId);
    final user = AppUser(
      uid: 'fayda_$cleanFin',
      name: fullName,
      phone: phoneNumber,
      role: UserRole.member,
      memberId: 'IDIR-F-${cleanFin.length >= 4 ? cleanFin.substring(cleanFin.length - 4) : cleanFin}',
      isActive: true,
      createdAt: DateTime.now(),
      faydaId: cleanFin,
      isFaydaVerified: true,
    );
    await _cacheUser(user);
    return user;
  }

  @override
  Future<AppUser> signInWithPassword({
    required String identifier,
    required String password,
  }) async {
    return signIn(email: identifier, password: password);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    // If user enters a 12-digit Fayda ID into any legacy field, route to Fayda verification
    final cleanInput = FaydaService.normalizeFin(email);
    if (cleanInput.length == 12 && RegExp(r'^\d{12}$').hasMatch(cleanInput)) {
      final demo = _findDemoUserByFaydaId(cleanInput);
      if (demo != null) {
        await _cacheUser(demo);
        return demo;
      }
      return verifyFaydaOtp(
        faydaId: cleanInput,
        otp: password.isNotEmpty ? password : '123456',
        txnId: 'TXN-LEGACY',
      );
    }

    throw Exception(
      'Authentication is restricted to Ethiopian National ID (Fayda). Please authenticate using your 12-digit Fayda ID.',
    );
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
        String name = map['name'] as String? ?? '';
        if (name.contains('Dawit Yohannes')) {
          name = name.replaceAll('Dawit Yohannes', 'Dawit Abdi');
        }
        return AppUser(
          uid: uid,
          name: name,
          phone: map['phone'] as String? ?? '',
          role: UserRoleX.fromString(map['role'] as String? ?? 'member'),
          memberId: map['memberId'] as String? ?? '',
          isActive: map['isActive'] as bool? ?? true,
          createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
              DateTime.now(),
          faydaId: map['faydaId'] as String?,
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
      if (user.faydaId != null) 'faydaId': user.faydaId,
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

  @override
  Future<AppUser> setSessionFromAuthResponse(Map<String, dynamic> responseData) async {
    final user = demoUsers.first;
    await _cacheUser(user);
    return user;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  final faydaService = ref.watch(faydaServiceProvider);
  return RestAuthRepository(
    apiClient: apiClient,
    cacheService: cache,
    faydaService: faydaService,
  );
});
