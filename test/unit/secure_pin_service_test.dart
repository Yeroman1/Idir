import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/core/constants/app_constants.dart';
import 'package:idir_app/core/services/secure_pin_service.dart';

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _storage.remove(key);
    } else {
      _storage[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage.containsKey(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.from(_storage);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SecurePinService unit tests', () {
    late FakeSecureStorage fakeStorage;
    late SecurePinService pinService;

    setUp(() {
      fakeStorage = FakeSecureStorage();
      pinService = SecurePinService(fakeStorage);
    });

    test('isPinSet returns false initially', () async {
      expect(await pinService.isPinSet(), isFalse);
    });

    test('setting and verifying a 4-digit PIN works correctly', () async {
      await pinService.setPin('1234');
      expect(await pinService.isPinSet(), isTrue);

      final result = await pinService.verifyPin('1234');
      expect(result, PinVerificationResult.success);
      expect(await pinService.getFailedAttempts(), 0);
    });

    test('incorrect PIN increments failed attempts', () async {
      await pinService.setPin('5555');

      final result1 = await pinService.verifyPin('1111');
      expect(result1, PinVerificationResult.incorrect);
      expect(await pinService.getFailedAttempts(), 1);

      final result2 = await pinService.verifyPin('2222');
      expect(result2, PinVerificationResult.incorrect);
      expect(await pinService.getFailedAttempts(), 2);
    });

    test('5 consecutive failed attempts causes lockout', () async {
      await pinService.setPin('9876');

      for (int i = 0; i < AppConstants.maxPinAttempts - 1; i++) {
        final res = await pinService.verifyPin('0000');
        expect(res, PinVerificationResult.incorrect);
      }

      // 5th attempt triggers lockout
      final lockoutRes = await pinService.verifyPin('0000');
      expect(lockoutRes, PinVerificationResult.lockedOut);

      // Subsequent attempt (even correct) remains locked out
      final subsequent = await pinService.verifyPin('9876');
      expect(subsequent, PinVerificationResult.lockedOut);
    });

    test('clearPin resets hash, salt, and attempts', () async {
      await pinService.setPin('1234');
      await pinService.clearPin();

      expect(await pinService.isPinSet(), isFalse);
      expect(await pinService.getFailedAttempts(), 0);
    });
  });
}
