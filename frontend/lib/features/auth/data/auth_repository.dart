import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/offline_cache_service.dart';
import 'rest_auth_repository.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Future<AppUser> signInWithPassword({
    required String identifier,
    required String password,
  });
  Future<AppUser> signIn({required String email, required String password});
  Future<void> signOut();
  Future<AppUser?> getCurrentUser();
  Future<void> updateProfile(AppUser user);
  Future<AppUser> setSessionFromAuthResponse(Map<String, dynamic> responseData);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  return RestAuthRepository(
    apiClient: apiClient,
    cacheService: cache,
  );
});
