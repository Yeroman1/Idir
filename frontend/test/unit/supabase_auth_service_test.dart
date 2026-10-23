import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/features/supabase_auth/services/auth_service.dart';

void main() {
  group('AuthService - Password Strength Validation', () {
    final authService = AuthService();

    test('valid strong password (12+ chars, upper, lower, digit, special) returns true', () {
      expect(authService.isPasswordStrong('SecureP@ssw0rd!'), isTrue);
      expect(authService.isPasswordStrong('Admin#2026_Valid'), isTrue);
    });

    test('less than 12 characters returns false', () {
      expect(authService.isPasswordStrong('Ab1!5678'), isFalse);
      expect(authService.hasMinLength('Ab1!5678'), isFalse);
    });

    test('missing uppercase returns false', () {
      expect(authService.isPasswordStrong('securep@ssw0rd!'), isFalse);
      expect(authService.hasUppercase('securep@ssw0rd!'), isFalse);
    });

    test('missing lowercase returns false', () {
      expect(authService.isPasswordStrong('SECUREP@SSW0RD!'), isFalse);
      expect(authService.hasLowercase('SECUREP@SSW0RD!'), isFalse);
    });

    test('missing digit returns false', () {
      expect(authService.isPasswordStrong('SecureP@ssword!'), isFalse);
      expect(authService.hasDigit('SecureP@ssword!'), isFalse);
    });

    test('missing special character returns false', () {
      expect(authService.isPasswordStrong('SecurePassw0rd1'), isFalse);
      expect(authService.hasSpecialChar('SecurePassw0rd1'), isFalse);
    });
  });

  group('AuthService - Profile Fields Validation', () {
    final authService = AuthService();

    test('Name validation rules (2-50 chars, letters only with spaces/hyphens)', () {
      expect(authService.isValidName('Abebe'), isTrue);
      expect(authService.isValidName('Haile-Mariam'), isTrue);
      expect(authService.isValidName('አበበ'), isTrue);
      expect(authService.isValidName('A'), isFalse); // < 2 chars
      expect(authService.isValidName('Abebe123'), isFalse); // digits not allowed
      expect(authService.isValidName('Abebe@#'), isFalse); // special symbols not allowed
    });

    test('Ethiopian Phone validation rules (+2519XXXXXXXX or +2517XXXXXXXX, exactly 13 chars)', () {
      expect(authService.isValidEthiopianPhone('+251911223344'), isTrue);
      expect(authService.isValidEthiopianPhone('+251711223344'), isTrue);
      expect(authService.isValidEthiopianPhone('0911223344'), isFalse); // missing +251
      expect(authService.isValidEthiopianPhone('+251811223344'), isFalse); // not 9 or 7
      expect(authService.isValidEthiopianPhone('+25191122334'), isFalse); // 12 chars
      expect(authService.isValidEthiopianPhone('+2519112233445'), isFalse); // 14 chars
    });

    test('Address validation rules (3-150 characters)', () {
      expect(authService.isValidAddress('Bole Subcity, Woreda 03, House 456, Addis Ababa'), isTrue);
      expect(authService.isValidAddress('Ab'), isFalse); // < 3 chars
    });

    test('Date of birth validation rules (at least 18 years old, cannot be in future)', () {
      final now = DateTime.now();
      final adultDob = DateTime(now.year - 25, now.month, now.day);
      final minorDob = DateTime(now.year - 16, now.month, now.day);
      final futureDob = DateTime(now.year + 1, now.month, now.day);

      expect(authService.isValidDateOfBirth(adultDob), isTrue);
      expect(authService.isValidDateOfBirth(minorDob), isFalse);
      expect(authService.isValidDateOfBirth(futureDob), isFalse);
      expect(authService.isValidDateOfBirth(null), isFalse);
    });
  });
}
