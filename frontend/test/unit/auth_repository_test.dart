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
  });
}
