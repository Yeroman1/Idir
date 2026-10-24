import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idir_app/core/constants/app_constants.dart';
import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/core/providers/active_idir_provider.dart';
import 'package:idir_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:idir_app/features/home/presentation/screens/home_screen.dart';
import 'package:idir_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:idir_app/features/settings/presentation/widgets/telegram_idir_switcher.dart';
import 'package:idir_app/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserMembership domain model tests', () {
    test('UserMembership serialization and deserialization', () {
      const membership = UserMembership(
        id: 'm-1',
        idirId: 'idir-101',
        idirName: 'Bole Medhanealem Yebego Adragot Idir',
        role: UserRole.chairperson,
        memberNumber: 'BM-001',
        status: 'ACTIVE',
        community: 'Bole Sub-City',
        location: 'Addis Ababa',
        contributionAmount: 200.0,
        contributionFrequency: 'MONTHLY',
      );

      final map = membership.toMap();
      expect(map['idirId'], 'idir-101');
      expect(map['idirName'], 'Bole Medhanealem Yebego Adragot Idir');
      expect(map['role'], 'chairperson');
      expect(map['memberNumber'], 'BM-001');
      expect(map['status'], 'ACTIVE');
      expect(map['community'], 'Bole Sub-City');
      expect(map['contributionAmount'], 200.0);

      final fromMap = UserMembership.fromMap(map);
      expect(fromMap, equals(membership));
      expect(fromMap.isActive, isTrue);
      expect(fromMap.isDraft, isFalse);
    });

    test('UserMembership handles draft status correctly', () {
      const draft = UserMembership(
        id: 'm-draft',
        idirId: 'draft-idir-1',
        idirName: 'Draft Community Idir',
        role: UserRole.chairperson,
        memberNumber: 'CREATOR-01',
        status: 'DRAFT',
      );
      expect(draft.isDraft, isTrue);
      expect(draft.isActive, isFalse);
    });

    test('AppUser holds and serializes multiple memberships', () {
      const m1 = UserMembership(
        id: 'm1',
        idirId: 'idir-1',
        idirName: 'Tinsae Mutual Aid',
        role: UserRole.chairperson,
        memberNumber: 'MEM-001',
        status: 'ACTIVE',
      );
      const m2 = UserMembership(
        id: 'm2',
        idirId: 'idir-2',
        idirName: 'Kirkos Community',
        role: UserRole.member,
        memberNumber: 'KC-042',
        status: 'ACTIVE',
      );

      final user = AppUser(
        uid: 'user-001',
        name: 'Tesfaye Lemma',
        phone: '+251911002233',
        role: UserRole.chairperson,
        memberId: 'MEM-001',
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
        idirId: 'idir-1',
        idirName: 'Tinsae Mutual Aid',
        memberships: const [m1, m2],
      );

      final map = user.toMap();
      expect(map['memberships'], isA<List>());
      expect((map['memberships'] as List).length, 2);

      final restored = AppUser.fromMap('user-001', map);
      expect(restored.memberships.length, 2);
      expect(restored.memberships[0].idirName, 'Tinsae Mutual Aid');
      expect(restored.memberships[1].idirName, 'Kirkos Community');
    });
  });

  group('ActiveIdirNotifier state management tests', () {
    test('Loads default sample Idirs and initializes active Idir', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(activeIdirProvider);
      expect(state.availableIdirs, isNotEmpty);
      expect(state.activeIdir, isNotNull);
      expect(state.activeIdir?.idirName, contains('Tinsae'));
    });

    test('switchIdir updates active Idir and persists to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(activeIdirProvider.notifier);
      await notifier.reloadIdirs();

      final available = container.read(activeIdirProvider).availableIdirs;
      expect(available.length, greaterThanOrEqualTo(2));

      final targetIdir = available[1]; // Switch to second Idir
      final result = await notifier.switchIdir(targetIdir.idirId);

      expect(result, isTrue);
      final updatedState = container.read(activeIdirProvider);
      expect(updatedState.activeIdir?.idirId, targetIdir.idirId);
      expect(updatedState.activeIdir?.idirName, targetIdir.idirName);

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.prefActiveIdirId), targetIdir.idirId);
    });

    test('addAndSwitchIdir adds new membership and switches active Idir immediately', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const newMembership = UserMembership(
        id: 'new-custom-idir',
        idirId: 'new-custom-idir',
        idirName: 'Hawassa Mutual Aid Association',
        role: UserRole.chairperson,
        memberNumber: 'HW-001',
        status: 'ACTIVE',
        community: 'Hawassa Tabor',
        location: 'Hawassa, Sidama',
        contributionAmount: 150.0,
      );

      final notifier = container.read(activeIdirProvider.notifier);
      await notifier.addAndSwitchIdir(newMembership);

      final state = container.read(activeIdirProvider);
      expect(state.activeIdir?.idirId, 'new-custom-idir');
      expect(state.activeIdir?.idirName, 'Hawassa Mutual Aid Association');
      expect(state.availableIdirs.any((m) => m.idirId == 'new-custom-idir'), isTrue);
    });
  });

  group('TelegramIdirSwitcherSection Widget tests', () {
    testWidgets('Renders Telegram-style account info, Idir list, and active checkmark',
        (tester) async {
      final testUser = AppUser(
        uid: 'u-456',
        name: 'Dawit Getachew',
        phone: '+251912345678',
        role: UserRole.chairperson,
        memberId: 'MEM-001',
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(testUser),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TelegramIdirSwitcherSection(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check account header
      expect(find.text('Dawit Getachew'), findsOneWidget);
      expect(find.text('+251912345678'), findsOneWidget);

      // Check Idir memberships title
      expect(find.text('IDIR MEMBERSHIPS'), findsOneWidget);

      // Check sample Idirs are listed
      expect(find.text('Tinsae Mutual Aid Association'), findsOneWidget);
      expect(find.text('Bole Medhanealem Yebego Adragot Idir'), findsOneWidget);

      // Check "+ Add or Join Idir" tile
      expect(find.text('Add or Join Idir'), findsOneWidget);

      // Check active checkmark is present on the active item
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('Tapping inactive Idir switches active state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TelegramIdirSwitcherSection(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially, active Idir is Tinsae
      expect(container.read(currentActiveIdirProvider)?.idirName,
          contains('Tinsae'));

      // Tap Bole Medhanealem Idir to switch
      final boleTile = find.text('Bole Medhanealem Yebego Adragot Idir');
      expect(boleTile, findsOneWidget);
      await tester.tap(boleTile);
      await tester.pumpAndSettle();

      // Check state switched to Bole Medhanealem
      expect(container.read(currentActiveIdirProvider)?.idirName,
          'Bole Medhanealem Yebego Adragot Idir');
      expect(find.textContaining('Switched to'), findsOneWidget);
    });

    testWidgets('SettingsScreen displays Account & Idir Switcher section at the top',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure Account & Idir Profiles header is visible
      expect(find.text('ACCOUNT & IDIR PROFILES'), findsOneWidget);
      expect(find.text('IDIR MEMBERSHIPS'), findsOneWidget);
      expect(find.text('Add or Join Idir'), findsOneWidget);
    });

    testWidgets('HomeScreen displays Current Active Idir prominently at top of dashboard',
        (tester) async {
      final testUser = AppUser(
        uid: 'user-home',
        name: 'Marta Hailu',
        phone: '+251922334455',
        role: UserRole.chairperson,
        memberId: 'MEM-001',
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
        idirId: 'idir_tinsae_001',
        idirName: 'Tinsae Mutual Aid Association',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(testUser),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Active Idir displayed at the top of dashboard (in AppBar & User profile card)
      expect(find.text('Tinsae Mutual Aid Association'), findsWidgets);
      expect(find.text('Marta Hailu'), findsOneWidget);
      expect(find.text('MEM-001'), findsWidgets);
    });
  });
}
