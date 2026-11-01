import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/core/network/api_client.dart';
import 'package:idir_app/core/storage/offline_cache_service.dart';
import 'package:idir_app/features/auth/data/rest_auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestAuthRepository Unit Tests', () {
    late ProviderContainer container;
    late RestAuthRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      repository = RestAuthRepository(
        apiClient: container.read(apiClientProvider),
        cacheService: OfflineCacheService(),
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial cached user is null when unauthenticated', () async {
      final user = await repository.getCurrentUser();
      expect(user, isNull);
    });

    test('setSessionFromAuthResponse parses verified user correctly', () async {
      final mockResponse = {
        'tokens': {
          'accessToken': 'mock-access-token',
          'refreshToken': 'mock-refresh-token',
        },
        'user': {
          'id': 'user-123',
          'fullName': 'Abebe Tadesse',
          'phoneNumber': '+251911223344',
          'role': 'CHAIRPERSON',
          'status': 'ACTIVE',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'memberships': [
            {
              'id': 'membership-1',
              'idirId': 'idir-1',
              'idirName': 'Tinsae Idir',
              'role': 'CHAIRPERSON',
              'memberNumber': 'IDIR-001',
              'status': 'ACTIVE',
            }
          ],
        },
      };

      final appUser = await repository.setSessionFromAuthResponse(mockResponse);
      expect(appUser.uid, 'user-123');
      expect(appUser.name, 'Abebe Tadesse');
      expect(appUser.role, UserRole.chairperson);
      expect(appUser.memberId, 'IDIR-001');

      final cached = await repository.getCurrentUser();
      expect(cached, isNotNull);
      expect(cached!.uid, 'user-123');
    });

    test('signOut clears cached user profile', () async {
      await repository.signOut();
      final user = await repository.getCurrentUser();
      expect(user, isNull);
    });

    test('setSessionFromAuthResponse parses email, address, and preferredLanguage', () async {
      final mockResponse = {
        'tokens': {
          'accessToken': 'mock-access-token',
          'refreshToken': 'mock-refresh-token',
        },
        'user': {
          'id': 'user-456',
          'fullName': 'Fatuma Roba',
          'phoneNumber': '+251911556677',
          'email': 'fatuma@example.com',
          'address': 'Kirkos Subcity, Woreda 02',
          'preferredLanguage': 'om',
          'role': 'MEMBER',
          'status': 'ACTIVE',
          'createdAt': '2026-02-01T00:00:00.000Z',
          'memberships': [],
        },
      };

      final appUser = await repository.setSessionFromAuthResponse(mockResponse);
      expect(appUser.uid, 'user-456');
      expect(appUser.name, 'Fatuma Roba');
      expect(appUser.email, 'fatuma@example.com');
      expect(appUser.address, 'Kirkos Subcity, Woreda 02');
      expect(appUser.preferredLanguage, 'om');

      final cached = await repository.getCurrentUser();
      expect(cached, isNotNull);
      expect(cached!.email, 'fatuma@example.com');
      expect(cached.address, 'Kirkos Subcity, Woreda 02');
      expect(cached.preferredLanguage, 'om');
    });

    test('AppUser copyWith maintains email immutability when updating profile fields', () {
      final user = AppUser(
        uid: 'user-789',
        name: 'Original Name',
        phone: '+251911111111',
        email: 'original@example.com',
        address: 'Old Address',
        preferredLanguage: 'am',
        role: UserRole.member,
        memberId: 'IDIR-001',
        isActive: true,
        createdAt: DateTime.now(),
      );

      final updated = user.copyWith(
        name: 'New Name',
        phone: '+251922222222',
        address: 'New Address',
        preferredLanguage: 'en',
      );

      expect(updated.name, 'New Name');
      expect(updated.phone, '+251922222222');
      expect(updated.address, 'New Address');
      expect(updated.preferredLanguage, 'en');
      // Email remains unchanged
      expect(updated.email, 'original@example.com');
    });
  });
}
