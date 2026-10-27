import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/core/network/api_client.dart';
import 'package:idir_app/core/providers/active_idir_provider.dart';
import 'package:idir_app/core/storage/offline_cache_service.dart';
import 'package:idir_app/features/auth/data/rest_auth_repository.dart';
import 'package:idir_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:idir_app/features/members/data/members_repository.dart';
import 'package:idir_app/features/members/presentation/screens/members_screen.dart';
import 'package:idir_app/l10n/app_localizations.dart';

class _FakeApiClient implements ApiClient {
  @override
  String get baseUrl => 'http://localhost:5000/api/v1';

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    if (path.contains('/members')) {
      throw ApiException(
        statusCode: 403,
        message: 'Only verified members of this Idir can view membership data.',
      );
    }
    return [];
  }

  @override
  Future<String?> getAccessToken() async => 'fake-token';

  @override
  Future<String?> getRefreshToken() async => 'fake-refresh-token';

  @override
  Future<void> clearTokens() async {}

  @override
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Membership Privacy & Scope Isolation Tests', () {
    test('User without memberships has null activeIdirIdProvider and does not default to Bole Medhanealem', () {
      final unaffiliatedUser = AppUser(
        uid: 'user-unaffiliated',
        name: 'Taera Daniel Hika',
        phone: '+251911002233',
        role: UserRole.member,
        memberId: 'MEM-UNAF',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        idirId: null,
        idirName: null,
        memberships: const [],
      );

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(unaffiliatedUser),
        ],
      );
      addTearDown(container.dispose);

      final activeId = container.read(activeIdirIdProvider);
      expect(activeId, isNull, reason: 'Unaffiliated users must not inherit a default idir ID');
      expect(container.read(currentActiveIdirProvider), isNull);
    });

    test('RestMembersRepository returns empty list when active idir is null', () async {
      final unaffiliatedUser = AppUser(
        uid: 'user-unaffiliated',
        name: 'Taera Daniel Hika',
        phone: '+251911002233',
        role: UserRole.member,
        memberId: 'MEM-UNAF',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        idirId: null,
        idirName: null,
        memberships: const [],
      );

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(unaffiliatedUser),
          apiClientProvider.overrideWithValue(_FakeApiClient()),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(membersRepositoryProvider);
      final members = await repo.getMembers();

      expect(members, isEmpty, reason: 'Members list must be empty for unaffiliated user');
    });

    testWidgets('MembersScreen displays privacy restriction notice when user has no active Idir', (tester) async {
      final unaffiliatedUser = AppUser(
        uid: 'user-unaffiliated',
        name: 'Taera Daniel Hika',
        phone: '+251911002233',
        role: UserRole.member,
        memberId: 'MEM-UNAF',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        idirId: null,
        idirName: null,
        memberships: const [],
      );

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(unaffiliatedUser),
          apiClientProvider.overrideWithValue(_FakeApiClient()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MembersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that privacy notice is displayed
      expect(find.text('Membership is private'), findsOneWidget);
      expect(find.textContaining('Idir membership lists are restricted to registered members'), findsOneWidget);

      // Verify that members from other Idirs (e.g. Yeroman Diriba or Abel Kebede) are NOT visible
      expect(find.text('Yeroman Diriba Guteta'), findsNothing);
      expect(find.text('Abel Kebede Tessema'), findsNothing);
    });

    test('RestAuthRepository.signOut clears all cached data across users', () async {
      final cacheService = OfflineCacheService();
      await cacheService.save('cache_members_bc39b889-4e08-4543-bb9e-db42c17ed901', [{'id': '1', 'name': 'Secret Member'}]);
      expect(await cacheService.has('cache_members_bc39b889-4e08-4543-bb9e-db42c17ed901'), isTrue);

      final authRepo = RestAuthRepository(
        apiClient: _FakeApiClient(),
        cacheService: cacheService,
      );

      await authRepo.signOut();

      // Offline cache should be completely wiped
      expect(await cacheService.has('cache_members_bc39b889-4e08-4543-bb9e-db42c17ed901'), isFalse);
    });
  });
}
