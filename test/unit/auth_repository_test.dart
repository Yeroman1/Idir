import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/features/auth/data/auth_repository.dart';
import 'package:idir_app/features/auth/data/fayda_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FirebaseAuthRepository Fayda National ID unit tests', () {
    late FirebaseAuthRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = FirebaseAuthRepository();
    });

    test('Fayda OTP request and verification signs in successfully with assigned roles', () async {
      // 1. Chairperson: 1000 2000 3001
      final chairOtpResp = await repository.requestFaydaOtp('1000 2000 3001');
      expect(chairOtpResp.isSuccess, isTrue);
      expect(chairOtpResp.maskedPhone, contains('+251'));
      expect(chairOtpResp.mockOtpCode, '123456');

      final chair = await repository.verifyFaydaOtp(
        faydaId: '1000 2000 3001',
        otp: chairOtpResp.mockOtpCode!,
        txnId: chairOtpResp.txnId,
      );
      expect(chair.role, UserRole.chairperson);
      expect(chair.faydaId, '100020003001');
      expect(chair.name, contains('Abebe'));

      // 2. Treasurer: 1000 2000 3002
      final treasurerOtp = await repository.requestFaydaOtp('1000 2000 3002');
      final treasurer = await repository.verifyFaydaOtp(
        faydaId: '1000 2000 3002',
        otp: treasurerOtp.mockOtpCode!,
        txnId: treasurerOtp.txnId,
      );
      expect(treasurer.role, UserRole.treasurer);
      expect(treasurer.faydaId, '100020003002');

      // 3. Auditor: 1000 2000 3003
      final auditorOtp = await repository.requestFaydaOtp('1000 2000 3003');
      final auditor = await repository.verifyFaydaOtp(
        faydaId: '1000 2000 3003',
        otp: auditorOtp.mockOtpCode!,
        txnId: auditorOtp.txnId,
      );
      expect(auditor.role, UserRole.auditor);
      expect(auditor.faydaId, '100020003003');

      // 4. Member: 1000 2000 3004
      final memberOtp = await repository.requestFaydaOtp('1000 2000 3004');
      final member = await repository.verifyFaydaOtp(
        faydaId: '1000 2000 3004',
        otp: memberOtp.mockOtpCode!,
        txnId: memberOtp.txnId,
      );
      expect(member.role, UserRole.member);
      expect(member.faydaId, '100020003004');
    });

    test('Current user persists with Fayda ID after verification and clears on sign-out', () async {
      final otp = await repository.requestFaydaOtp('1000 2000 3002');
      await repository.verifyFaydaOtp(
        faydaId: '1000 2000 3002',
        otp: otp.mockOtpCode!,
        txnId: otp.txnId,
      );

      final current = await repository.getCurrentUser();
      expect(current, isNotNull);
      expect(current!.role, UserRole.treasurer);
      expect(current.faydaId, '100020003002');

      await repository.signOut();
      final afterSignOut = await repository.getCurrentUser();
      expect(afterSignOut, isNull);
    });

    test('updateProfile updates and persists modified profile fields with Fayda ID preserved', () async {
      final otp = await repository.requestFaydaOtp('1000 2000 3004');
      final user = await repository.verifyFaydaOtp(
        faydaId: '1000 2000 3004',
        otp: otp.mockOtpCode!,
        txnId: otp.txnId,
      );

      final updated = user.copyWith(name: 'Fatima Updated', phone: '+251 99 999 9999');
      await repository.updateProfile(updated);

      final cached = await repository.getCurrentUser();
      expect(cached, isNotNull);
      expect(cached!.name, 'Fatima Updated');
      expect(cached.phone, '+251 99 999 9999');
      expect(cached.faydaId, '100020003004');
      expect(cached.role, UserRole.member);
    });

    test('Legacy email login is rejected with Fayda requirement error', () async {
      expect(
        () => repository.signIn(email: 'user@example.com', password: 'password123'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('restricted to Ethiopian National ID (Fayda)'),
        )),
      );
    });

    test('FaydaService normalizes and formats 12-digit FIN correctly', () {
      expect(FaydaService.normalizeFin('1000 2000 3001'), '100020003001');
      expect(FaydaService.normalizeFin('1000-2000-3001'), '100020003001');
      expect(FaydaService.formatFin('100020003001'), '1000 2000 3001');
    });
  });
}
