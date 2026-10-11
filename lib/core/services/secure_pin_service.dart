import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

enum PinVerificationResult {
  success,
  incorrect,
  lockedOut,
  notSet,
}

/// Secure storage provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

/// Service managing PIN hashing, verification, lockout, and secure persistence.
class SecurePinService {
  const SecurePinService(this._storage);

  final FlutterSecureStorage _storage;

  /// Checks if a PIN has been established.
  Future<bool> isPinSet() async {
    final hash = await _storage.read(key: AppConstants.secureKeyPin);
    return hash != null && hash.isNotEmpty;
  }

  /// Sets or updates the 4-digit PIN using SHA-256 with salt.
  Future<void> setPin(String pin) async {
    if (pin.length < 4) {
      throw ArgumentError('PIN must be at least 4 digits');
    }
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);

    await _storage.write(key: AppConstants.secureKeyPin, value: hash);
    await _storage.write(key: AppConstants.secureKeyPinSalt, value: salt);
    await resetFailedAttempts();
  }

  /// Verifies the entered PIN against stored secure hash.
  Future<PinVerificationResult> verifyPin(String pin) async {
    final attempts = await getFailedAttempts();
    if (attempts >= AppConstants.maxPinAttempts) {
      return PinVerificationResult.lockedOut;
    }

    final hash = await _storage.read(key: AppConstants.secureKeyPin);
    final salt = await _storage.read(key: AppConstants.secureKeyPinSalt);

    if (hash == null || salt == null) {
      return PinVerificationResult.notSet;
    }

    final inputHash = _hashPin(pin, salt);
    if (inputHash == hash) {
      await resetFailedAttempts();
      return PinVerificationResult.success;
    } else {
      final newAttempts = await _incrementFailedAttempts();
      if (newAttempts >= AppConstants.maxPinAttempts) {
        return PinVerificationResult.lockedOut;
      }
      return PinVerificationResult.incorrect;
    }
  }

  /// Number of consecutive failed attempts.
  Future<int> getFailedAttempts() async {
    final raw = await _storage.read(key: AppConstants.secureKeyPinAttempts);
    return int.tryParse(raw ?? '0') ?? 0;
  }

  /// Resets failed attempts to 0.
  Future<void> resetFailedAttempts() async {
    await _storage.write(
      key: AppConstants.secureKeyPinAttempts,
      value: '0',
    );
  }

  /// Removes the stored PIN entirely.
  Future<void> clearPin() async {
    await _storage.delete(key: AppConstants.secureKeyPin);
    await _storage.delete(key: AppConstants.secureKeyPinSalt);
    await resetFailedAttempts();
  }

  Future<int> _incrementFailedAttempts() async {
    final current = await getFailedAttempts();
    final updated = current + 1;
    await _storage.write(
      key: AppConstants.secureKeyPinAttempts,
      value: updated.toString(),
    );
    return updated;
  }

  String _generateSalt() {
    final rnd = Random.secure();
    final values = List<int>.generate(16, (i) => rnd.nextInt(256));
    return base64Url.encode(values);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}

final securePinServiceProvider = Provider<SecurePinService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return SecurePinService(storage);
});
