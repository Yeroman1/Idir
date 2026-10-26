import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/offline_cache_service.dart';
import 'auth_repository.dart';

class RestAuthRepository implements AuthRepository {
  RestAuthRepository({
    required ApiClient apiClient,
    required OfflineCacheService cacheService,
  })  : _apiClient = apiClient,
        _cache = cacheService;

  final ApiClient _apiClient;
  final OfflineCacheService _cache;

  static const _cacheKey = 'cached_user_profile';

  @override
  Stream<AppUser?> authStateChanges() async* {
    final cached = await getCurrentUser();
    yield cached;
  }

  @override
  Future<AppUser> signInWithPassword({
    required String identifier,
    required String password,
  }) async {
    final cleanInput = identifier.trim();
    try {
      final res = await _apiClient.post(
        '/auth/login',
        body: {
          'email': cleanInput.contains('@') ? cleanInput.toLowerCase() : null,
          'phoneNumber': cleanInput.contains('@') ? null : cleanInput,
          'password': password,
        },
        requiresAuth: false,
      );

      final appUser = await _parseUserResponse(res);
      await _cacheUser(appUser);
      return appUser;
    } on ApiException catch (e) {
      if (e.isOffline) {
        throw Exception(
          'Network error: You must be online to sign in with your password. Please check your internet connection.',
        );
      }
      rethrow;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('connection refused') ||
          msg.contains('timed out') ||
          msg.contains('failed host lookup') ||
          msg.contains('unable to connect')) {
        throw Exception(
          'Network error: You must be online to sign in with your password. Please check your internet connection.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    return signInWithPassword(identifier: email, password: password);
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    // 1. Check local cache first
    final cachedJson = await _cache.read(_cacheKey);
    AppUser? cachedUser;
    if (cachedJson is Map<String, dynamic>) {
      cachedUser = _userFromMap(cachedJson);
    }

    // 2. If online and token available, refresh profile from /auth/me
    final token = await _apiClient.getAccessToken();
    if (token != null && token.isNotEmpty) {
      try {
        final res = await _apiClient.get('/auth/me');
        if (res is Map<String, dynamic>) {
          final refreshed = await _userFromBackendJson(res);
          await _cacheUser(refreshed);
          return refreshed;
        }
      } catch (e) {
        debugPrint('[RestAuthRepository] /auth/me skipped: $e');
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
    await _cache.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefIsLoggedIn, false);
    await prefs.remove(AppConstants.prefActiveIdirId);
  }

  @override
  Future<AppUser> setSessionFromAuthResponse(Map<String, dynamic> responseData) async {
    final appUser = await _parseUserResponse(responseData);
    await _cacheUser(appUser);
    return appUser;
  }

  Future<AppUser> _parseUserResponse(dynamic res) async {
    if (res is! Map<String, dynamic>) {
      throw Exception('Unexpected response format from authentication server');
    }

    // Save JWT tokens
    final tokens = res['tokens'] as Map<String, dynamic>?;
    if (tokens != null) {
      final access = tokens['accessToken'] as String?;
      final refresh = tokens['refreshToken'] as String?;
      if (access != null && refresh != null) {
        await _apiClient.saveTokens(accessToken: access, refreshToken: refresh);
      }
    }

    final userData = res['user'] as Map<String, dynamic>? ?? res;
    return _userFromBackendJson(userData);
  }

  Future<AppUser> _userFromBackendJson(Map<String, dynamic> json) async {
    final uid = json['id'] as String? ?? json['uid'] as String? ?? '';
    final name = json['fullName'] as String? ?? json['name'] as String? ?? '';
    final phone = json['phoneNumber'] as String? ?? json['phone'] as String? ?? '';
    final isActive = json['status'] == 'ACTIVE' || json['isActive'] == true;
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    final preferredActiveIdirId = prefs.getString(AppConstants.prefActiveIdirId);

    // Determine role, member ID, and Idir affiliation from memberships array
    UserRole role = UserRole.member;
    String memberId = 'IDIR-${uid.isNotEmpty ? uid.substring(0, uid.length.clamp(0, 6)) : "001"}';
    String? idirId;
    String? idirName;

    final membershipsRaw = json['memberships'] as List<dynamic>?;
    final List<UserMembership> memberships = [];

    if (membershipsRaw != null && membershipsRaw.isNotEmpty) {
      for (final item in membershipsRaw) {
        if (item is Map<String, dynamic>) {
          memberships.add(UserMembership.fromMap(item));
        }
      }

      // Pick active membership based on user preference or first available
      UserMembership? selected;
      if (preferredActiveIdirId != null &&
          preferredActiveIdirId != '00000000-0000-0000-0000-000000000001') {
        selected = memberships.where((m) => m.idirId == preferredActiveIdirId).firstOrNull;
      }
      selected ??= memberships.where((m) => m.idirId != '00000000-0000-0000-0000-000000000001').firstOrNull;
      selected ??= memberships.first;

      role = selected.role;
      memberId = selected.memberNumber.isNotEmpty ? selected.memberNumber : memberId;
      idirId = selected.idirId;
      idirName = selected.idirName;

      // Always persist real active ID
      if (idirId.isNotEmpty && idirId != '00000000-0000-0000-0000-000000000001') {
        await prefs.setString(AppConstants.prefActiveIdirId, idirId);
      }
    } else {
      await prefs.remove(AppConstants.prefActiveIdirId);
      if (json['role'] != null) {
        role = UserRoleX.fromString(json['role'] as String);
      }
    }

    return AppUser(
      uid: uid,
      name: name,
      phone: phone,
      role: role,
      memberId: memberId,
      isActive: isActive,
      createdAt: createdAt,
      idirId: idirId,
      idirName: idirName,
      memberships: memberships,
    );
  }

  AppUser _userFromMap(Map<String, dynamic> map) {
    final membershipsList = (map['memberships'] as List<dynamic>?)
            ?.map((m) => UserMembership.fromMap(m as Map<String, dynamic>))
            .toList() ??
        const [];

    return AppUser(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: UserRoleX.fromString(map['role'] as String? ?? 'member'),
      memberId: map['memberId'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      idirId: map['idirId'] as String?,
      idirName: map['idirName'] as String?,
      memberships: membershipsList,
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
      if (user.idirId != null) 'idirId': user.idirId,
      if (user.idirName != null) 'idirName': user.idirName,
      'memberships': user.memberships.map((m) => m.toMap()).toList(),
    };

    await _cache.save(_cacheKey, map);
  }
}
