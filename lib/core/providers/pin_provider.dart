import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../services/secure_pin_service.dart';

class PinState extends Equatable {
  const PinState({
    required this.isSet,
    required this.isUnlocked,
    required this.failedAttempts,
    required this.isLockedOut,
    required this.isLoading,
  });

  final bool isSet;
  final bool isUnlocked;
  final int failedAttempts;
  final bool isLockedOut;
  final bool isLoading;

  int get remainingAttempts =>
      (AppConstants.maxPinAttempts - failedAttempts).clamp(0, AppConstants.maxPinAttempts);

  PinState copyWith({
    bool? isSet,
    bool? isUnlocked,
    int? failedAttempts,
    bool? isLockedOut,
    bool? isLoading,
  }) {
    return PinState(
      isSet: isSet ?? this.isSet,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      isLockedOut: isLockedOut ?? this.isLockedOut,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props =>
      [isSet, isUnlocked, failedAttempts, isLockedOut, isLoading];
}

class PinNotifier extends StateNotifier<PinState> {
  PinNotifier(this._pinService)
      : super(const PinState(
          isSet: false,
          isUnlocked: false,
          failedAttempts: 0,
          isLockedOut: false,
          isLoading: true,
        )) {
    init();
  }

  final SecurePinService _pinService;

  Future<void> init() async {
    final isSet = await _pinService.isPinSet();
    final attempts = await _pinService.getFailedAttempts();
    final isLockedOut = attempts >= AppConstants.maxPinAttempts;

    state = state.copyWith(
      isSet: isSet,
      isUnlocked: !isSet, // If no PIN is configured, unlocked by default
      failedAttempts: attempts,
      isLockedOut: isLockedOut,
      isLoading: false,
    );
  }

  /// Verifies the entered PIN and updates unlock status.
  Future<PinVerificationResult> unlock(String pin) async {
    final result = await _pinService.verifyPin(pin);
    final attempts = await _pinService.getFailedAttempts();
    final isLockedOut = result == PinVerificationResult.lockedOut;

    if (result == PinVerificationResult.success) {
      state = state.copyWith(
        isUnlocked: true,
        failedAttempts: 0,
        isLockedOut: false,
      );
    } else {
      state = state.copyWith(
        failedAttempts: attempts,
        isLockedOut: isLockedOut,
      );
    }
    return result;
  }

  /// Configures a new PIN and marks session unlocked.
  Future<void> setupPin(String pin) async {
    await _pinService.setPin(pin);
    state = state.copyWith(
      isSet: true,
      isUnlocked: true,
      failedAttempts: 0,
      isLockedOut: false,
    );
  }

  /// Manually locks the app session.
  void lock() {
    if (state.isSet) {
      state = state.copyWith(isUnlocked: false);
    }
  }

  /// Clears stored PIN.
  Future<void> clearPin() async {
    await _pinService.clearPin();
    state = state.copyWith(
      isSet: false,
      isUnlocked: true,
      failedAttempts: 0,
      isLockedOut: false,
    );
  }
}

final pinNotifierProvider =
    StateNotifierProvider<PinNotifier, PinState>((ref) {
  final pinService = ref.watch(securePinServiceProvider);
  return PinNotifier(pinService);
});
