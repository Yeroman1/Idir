import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FirebaseAuthRepository unit tests', () {
    late FirebaseAuthRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = FirebaseAuthRepository();
    });

    test('Demo accounts sign in successfully with correct roles', () async {
      final chair = await repository.signIn(
        email: 'chair@idir.org',
        password: 'chair123',
      );
      expect(chair.role, UserRole.chairperson);
      expect(chair.name, contains('Chairperson'));

      final treasurer = await repository.signIn(
        email: 'treasurer@idir.org',
        password: 'treasurer123',
      );
      expect(treasurer.role, UserRole.treasurer);

      final auditor = await repository.signIn(
        email: 'auditor@idir.org',
        password: 'auditor123',
      );
      expect(auditor.role, UserRole.auditor);

      final member = await repository.signIn(
        email: 'member@idir.org',
        password: 'member123',
      );
      expect(member.role, UserRole.member);
    });

    test('Current user persists after sign-in and clears on sign-out', () async {
      await repository.signIn(
        email: 'treasurer@idir.org',
        password: 'treasurer123',
      );

      final current = await repository.getCurrentUser();
      expect(current, isNotNull);
      expect(current!.role, UserRole.treasurer);

      await repository.signOut();
      final afterSignOut = await repository.getCurrentUser();
      expect(afterSignOut, isNull);
    });

    test('updateProfile updates and persists modified profile fields', () async {
      final user = await repository.signIn(
        email: 'member@idir.org',
        password: 'member123',
      );

      final updated =
          user.copyWith(name: 'Fatima Updated', phone: '+251 99 999 9999');
      await repository.updateProfile(updated);

      final cached = await repository.getCurrentUser();
      expect(cached, isNotNull);
      expect(cached!.name, 'Fatima Updated');
      expect(cached.phone, '+251 99 999 9999');
      expect(cached.role, UserRole.member);
    });
  });
}
