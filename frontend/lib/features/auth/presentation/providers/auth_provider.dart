import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/providers/pin_provider.dart';
import '../../../../core/providers/sync_status_provider.dart';
import '../../data/auth_repository.dart';
import '../../data/fayda_service.dart';

class AuthState extends Equatable {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isInitialized = false,
    this.faydaId,
    this.txnId,
    this.maskedPhone,
    this.isOtpSent = false,
    this.mockOtpHint,
  });

  final AppUser? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isInitialized;

  // Fayda 2-step verification states
  final String? faydaId;
  final String? txnId;
  final String? maskedPhone;
  final bool isOtpSent;
  final String? mockOtpHint;

  bool get isAuthenticated => user != null;
  UserRole? get role => user?.role;

  AuthState copyWith({
    AppUser? Function()? user,
    bool? isLoading,
    String? Function()? errorMessage,
    bool? isInitialized,
    String? Function()? faydaId,
    String? Function()? txnId,
    String? Function()? maskedPhone,
    bool? isOtpSent,
    String? Function()? mockOtpHint,
  }) {
    return AuthState(
      user: user != null ? user() : this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
      isInitialized: isInitialized ?? this.isInitialized,
      faydaId: faydaId != null ? faydaId() : this.faydaId,
      txnId: txnId != null ? txnId() : this.txnId,
      maskedPhone: maskedPhone != null ? maskedPhone() : this.maskedPhone,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      mockOtpHint: mockOtpHint != null ? mockOtpHint() : this.mockOtpHint,
    );
  }

  @override
  List<Object?> get props => [
        user,
        isLoading,
        errorMessage,
        isInitialized,
        faydaId,
        txnId,
        maskedPhone,
        isOtpSent,
        mockOtpHint,
      ];
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._ref)
      : super(const AuthState(isLoading: true)) {
    _init();
  }

  final AuthRepository _repository;
  final Ref _ref;

  Future<void> _init() async {
    final cached = await _repository.getCurrentUser();
    state = AuthState(
      user: cached,
      isLoading: false,
      isInitialized: true,
    );
    _ref.read(syncProvider.notifier).registerSyncCallback(refreshCurrentUser);
  }

  /// Refreshes current user profile directly from live backend / Supabase
  Future<void> refreshCurrentUser() async {
    try {
      final fresh = await _repository.getCurrentUser();
      if (fresh != null && fresh != state.user) {
        state = state.copyWith(user: () => fresh);
      }
    } catch (_) {}
  }

  /// Step 1: Send OTP to the citizen's phone registered with their Ethiopian National ID (Fayda)
  Future<bool> requestFaydaOtp(String faydaId) async {
    final cleanFin = FaydaService.normalizeFin(faydaId);
    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final response = await _repository.requestFaydaOtp(cleanFin);
      state = state.copyWith(
        isLoading: false,
        isOtpSent: true,
        faydaId: () => cleanFin,
        txnId: () => response.txnId,
        maskedPhone: () => response.maskedPhone,
        mockOtpHint: () => response.mockOtpCode,
        errorMessage: () => null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isOtpSent: false,
        errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Step 2: Verify OTP via Fayda API and complete institutional login
  Future<bool> verifyFaydaOtp(String otp) async {
    final fin = state.faydaId;
    final txnId = state.txnId ?? '';

    if (fin == null || fin.isEmpty) {
      state = state.copyWith(
        errorMessage: () => 'Missing Fayda National ID. Please request OTP again.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final user = await _repository.verifyFaydaOtp(
        faydaId: fin,
        otp: otp,
        txnId: txnId,
      );

      state = state.copyWith(
        user: () => user,
        isLoading: false,
        isOtpSent: false,
        faydaId: () => null,
        txnId: () => null,
        maskedPhone: () => null,
        mockOtpHint: () => null,
        errorMessage: () => null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Cancel OTP flow and return to entering Fayda ID
  void resetOtpFlow() {
    state = state.copyWith(
      isOtpSent: false,
      txnId: () => null,
      maskedPhone: () => null,
      mockOtpHint: () => null,
      errorMessage: () => null,
    );
  }

  /// Legacy signIn fallback (routes to Fayda)
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final user = await _repository.signIn(email: email, password: password);
      state = state.copyWith(
        user: () => user,
        isLoading: false,
        errorMessage: () => null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await _repository.signOut();
    _ref.read(pinNotifierProvider.notifier).lock();
    state = const AuthState(
      user: null,
      isLoading: false,
      isInitialized: true,
    );
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    final current = state.user;
    if (current == null) return;
    final updated = current.copyWith(name: name, phone: phone);
    await _repository.updateProfile(updated);
    state = state.copyWith(user: () => updated);
  }

  Future<void> switchRole(UserRole newRole) async {
    final current = state.user;
    if (current == null) return;
    final updated = current.copyWith(role: newRole);
    await _repository.updateProfile(updated);
    state = state.copyWith(user: () => updated);
  }

  Future<void> switchDemoUser(AppUser demoUser) async {
    final fin = demoUser.faydaId;
    if (fin != null && fin.isNotEmpty) {
      try {
        final liveUser = await _repository.verifyFaydaOtp(
          faydaId: fin,
          otp: '123456',
          txnId: 'TXN-SWITCH',
        );
        state = state.copyWith(user: () => liveUser);
        await _ref.read(syncProvider.notifier).triggerSync();
        return;
      } catch (_) {}
    }
    await _repository.updateProfile(demoUser);
    state = state.copyWith(user: () => demoUser);
  }

  void clearError() {
    state = state.copyWith(errorMessage: () => null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo, ref);
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authNotifierProvider).user;
});
