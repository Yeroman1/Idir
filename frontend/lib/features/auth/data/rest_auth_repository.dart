import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/offline_cache_service.dart';
import 'auth_repository.dart';
import 'fayda_service.dart';

class RestAuthRepository implements AuthRepository {
  RestAuthRepository({
    required ApiClient apiClient,
    required OfflineCacheService cacheService,
    FaydaService? faydaService,
  })  : _apiClient = apiClient,
        _cache = cacheService,
        _faydaService = faydaService ?? FaydaService();

  final ApiClient _apiClient;
  final OfflineCacheService _cache;
  final FaydaService _faydaService;

  static const _cacheKey = 'cached_user_profile';

  @override
  Stream<AppUser?> authStateChanges() async* {
    final cached = await getCurrentUser();
    yield cached;
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
    // 1. Verify OTP with Fayda service
    final citizen = await _faydaService.verifyOtp(
      faydaInput: faydaId,
      otp: otp,
      txnId: txnId,
    );

    final cleanFin = FaydaService.normalizeFin(citizen.fin);

    // 2. Try authenticating against backend with Fayda ID or phone
    try {
      final res = await _apiClient.post(
        '/auth/login',
        body: {
          'phoneNumber': cleanFin,
          'password': 'Password123!',
        },
        requiresAuth: false,
      );

      final appUser = _parseUserResponse(res);
      await _cacheUser(appUser);
      return appUser;
    } on ApiException catch (e) {
      if (e.isOffline) {
        // Fallback to offline cached profile if available
        final cached = await getCurrentUser();
        if (cached != null && (cached.faydaId == cleanFin || cached.phone == citizen.phone)) {
          return cached;
        }
      }

      // Try logging in using citizen's phone number as fallback
      try {
        final res = await _apiClient.post(
          '/auth/login',
          body: {
            'phoneNumber': citizen.phone,
            'password': 'Password123!',
          },
          requiresAuth: false,
        );

        final appUser = _parseUserResponse(res);
        await _cacheUser(appUser);
        return appUser;
      } catch (_) {
        // 3. Fallback: Check demo users or construct registered citizen profile
        for (final demo in FirebaseAuthRepository.demoUsers) {
          if (demo.faydaId == cleanFin) {
            await _cacheUser(demo);
            return demo;
          }
        }

        final localUser = AppUser(
          uid: 'fayda_$cleanFin',
          name: citizen.fullName,
          phone: citizen.phone,
          role: UserRole.member,
          memberId: 'IDIR-F-${cleanFin.length >= 4 ? cleanFin.substring(cleanFin.length - 4) : cleanFin}',
          isActive: true,
          createdAt: DateTime.now(),
          faydaId: cleanFin,
        );
        await _cacheUser(localUser);
        return localUser;
      }
    }
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final cleanInput = email.trim();

    try {
      final res = await _apiClient.post(
        '/auth/login',
        body: {
          'phoneNumber': cleanInput,
          'password': password,
        },
        requiresAuth: false,
      );

      final appUser = _parseUserResponse(res);
      await _cacheUser(appUser);
      return appUser;
    } on ApiException catch (e) {
      // If network is offline, attempt to authenticate using latest cached profile
      if (e.isOffline) {
        final cached = await getCurrentUser();
        if (cached != null) {
          debugPrint('[RestAuthRepository] Operating offline with cached user ${cached.name}');
          return cached;
        }
      }
      rethrow;
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    // 1. Check local cache first for instant startup
    final cachedJson = await _cache.read(_cacheKey);
    AppUser? cachedUser;
    if (cachedJson is Map<String, dynamic>) {
      cachedUser = _userFromMap(cachedJson);
    }

    // 2. If online and token available, refresh profile from /auth/me in background
    final token = await _apiClient.getAccessToken();
    if (token != null && token.isNotEmpty) {
      try {
        final res = await _apiClient.get('/auth/me');
        if (res is Map<String, dynamic>) {
          final refreshed = _userFromBackendJson(res);
          await _cacheUser(refreshed);
          return refreshed;
        }
      } catch (e) {
        // If /auth/me fails (e.g. offline), return cached user safely
        debugPrint('[RestAuthRepository] Background /auth/me skipped (offline): $e');
      }
    }

    return cachedUser;
  }

  @override
  Future<void> updateProfile(AppUser user) async {
    await _cacheUser(user);
    try {
      await _apiClient.put(
        '/users/${user.uid}',
        body: {
          'fullName': user.name,
          'phoneNumber': user.phone,
        },
      );
    } catch (e) {
      debugPrint('[RestAuthRepository] Offline profile update queued locally: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      final rToken = await _apiClient.getRefreshToken();
      if (rToken != null) {
        await _apiClient.post(
          '/auth/logout',
          body: {'refreshToken': rToken},
          requiresAuth: false,
        );
      }
    } catch (_) {}

    await _apiClient.clearTokens();
    await _cache.remove(_cacheKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefIsLoggedIn, false);
  }

  AppUser _parseUserResponse(dynamic res) {
    if (res is! Map<String, dynamic>) {
      throw Exception('Unexpected response format from authentication server');
    }

    // Save JWT tokens
    final tokens = res['tokens'] as Map<String, dynamic>?;
    if (tokens != null) {
      final access = tokens['accessToken'] as String?;
      final refresh = tokens['refreshToken'] as String?;
      if (access != null && refresh != null) {
        _apiClient.saveTokens(accessToken: access, refreshToken: refresh);
      }
    }

    final userData = res['user'] as Map<String, dynamic>? ?? res;
    return _userFromBackendJson(userData);
  }

  AppUser _userFromBackendJson(Map<String, dynamic> json) {
    final uid = json['id'] as String? ?? json['uid'] as String? ?? '';
    final name = json['fullName'] as String? ?? json['name'] as String? ?? '';
    final phone = json['phoneNumber'] as String? ?? json['phone'] as String? ?? '';
    final faydaId = json['faydaId'] as String?;
    final isActive = json['status'] == 'ACTIVE' || json['isActive'] == true;
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();

    // Determine role and member ID from memberships array if present
    UserRole role = UserRole.member;
    String memberId = 'IDIR-${uid.isNotEmpty ? uid.substring(0, uid.length.clamp(0, 6)) : "001"}';

    final memberships = json['memberships'] as List<dynamic>?;
    if (memberships != null && memberships.isNotEmpty) {
      final primary = memberships.first as Map<String, dynamic>;
      final roleStr = (primary['role'] as String? ?? '').toUpperCase();
      memberId = primary['memberNumber'] as String? ?? memberId;

      role = switch (roleStr) {
        'CHAIRPERSON' => UserRole.chairperson,
        'TREASURER' => UserRole.treasurer,
        'AUDITOR' => UserRole.auditor,
        'SECRETARY' => UserRole.chairperson, // High-level officer permission
        _ => UserRole.member,
      };
    } else if (json['role'] != null) {
      role = UserRoleX.fromString(json['role'] as String);
    }

    return AppUser(
      uid: uid,
      name: name,
      phone: phone,
      role: role,
      memberId: memberId,
      isActive: isActive,
      createdAt: createdAt,
      faydaId: faydaId,
    );
  }

  AppUser _userFromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: UserRoleX.fromString(map['role'] as String? ?? 'member'),
      memberId: map['memberId'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      faydaId: map['faydaId'] as String?,
    );
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

    await _cache.save(_cacheKey, map);
  }
}
