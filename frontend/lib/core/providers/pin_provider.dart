import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../services/secure_pin_service.dart';

class PinState extends Equatable {
  const PinState({
    required this.isSet,
    required this.isUnlocked,
    required this.failedAttempts,
    required this.isLockedOut,
    required this.isLoading,
    this.isPinEnabled = false,
  });

  final bool isSet;
  final bool isUnlocked;
  final int failedAttempts;
  final bool isLockedOut;
  final bool isLoading;
  final bool isPinEnabled;

  int get remainingAttempts =>
      (AppConstants.maxPinAttempts - failedAttempts).clamp(0, AppConstants.maxPinAttempts);

  PinState copyWith({
    bool? isSet,
    bool? isUnlocked,
    int? failedAttempts,
    bool? isLockedOut,
    bool? isLoading,
    bool? isPinEnabled,
  }) {
    return PinState(
      isSet: isSet ?? this.isSet,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      isLockedOut: isLockedOut ?? this.isLockedOut,
      isLoading: isLoading ?? this.isLoading,
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
    );
  }

  @override
  List<Object?> get props =>
      [isSet, isUnlocked, failedAttempts, isLockedOut, isLoading, isPinEnabled];
}

class PinNotifier extends StateNotifier<PinState> {
  PinNotifier(this._pinService)
      : super(const PinState(
          isSet: false,
          isUnlocked: true,
          failedAttempts: 0,
          isLockedOut: false,
          isLoading: true,
          isPinEnabled: false,
        )) {
    init();
  }

  final SecurePinService _pinService;
  static const _prefPinEnabledKey = 'pref_pin_lock_enabled';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // Default is false: PIN lock is optional and NOT needed by default
    final isPinEnabled = prefs.getBool(_prefPinEnabledKey) ?? false;
    final isSet = await _pinService.isPinSet();
    final attempts = await _pinService.getFailedAttempts();
    final isLockedOut = attempts >= AppConstants.maxPinAttempts;

    state = state.copyWith(
      isSet: isSet,
      isPinEnabled: isPinEnabled,
      // If PIN lock is disabled, session is ALWAYS unlocked
      isUnlocked: !isPinEnabled || !isSet,
      failedAttempts: attempts,
      isLockedOut: isLockedOut,
      isLoading: false,
    );
  }

  /// Sets whether the optional PIN lock feature is enabled by the user.
  Future<void> setPinEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefPinEnabledKey, enabled);
    state = state.copyWith(
      isPinEnabled: enabled,
      isUnlocked: !enabled ? true : state.isUnlocked,
    );
  }

  /// Immediately unlocks the PIN session (e.g. upon successful email/password login).
  void unlockSession() {
    state = state.copyWith(
      isUnlocked: true,
      failedAttempts: 0,
      isLockedOut: false,
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

  /// Configures a new PIN, enables it, and marks session unlocked.
  Future<void> setupPin(String pin) async {
    await _pinService.setPin(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefPinEnabledKey, true);
    state = state.copyWith(
      isSet: true,
      isPinEnabled: true,
      isUnlocked: true,
      failedAttempts: 0,
      isLockedOut: false,
    );
  }

  /// Manually locks the app session ONLY if PIN lock is explicitly enabled.
  void lock() {
    if (state.isPinEnabled && state.isSet) {
      state = state.copyWith(isUnlocked: false);
    }
  }

  /// Clears stored PIN and disables PIN lock.
  Future<void> clearPin() async {
    await _pinService.clearPin();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefPinEnabledKey, false);
    state = state.copyWith(
      isSet: false,
      isPinEnabled: false,
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
