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
    this.verifiedCitizen,
    this.isFaydaOtpVerified = false,
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

  // Verified Fayda citizen profile awaiting password creation
  final FaydaCitizenProfile? verifiedCitizen;
  final bool isFaydaOtpVerified;

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
    FaydaCitizenProfile? Function()? verifiedCitizen,
    bool? isFaydaOtpVerified,
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
      verifiedCitizen:
          verifiedCitizen != null ? verifiedCitizen() : this.verifiedCitizen,
      isFaydaOtpVerified: isFaydaOtpVerified ?? this.isFaydaOtpVerified,
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
        verifiedCitizen,
        isFaydaOtpVerified,
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
    if (!mounted) return;
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
      if (!mounted) return;
      if (fresh != null && fresh != state.user) {
        state = state.copyWith(user: () => fresh);
      }
    } catch (_) {}
  }

  /// Step 1: Send OTP to citizen's phone via Ethiopian National ID (Fayda)
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
        isFaydaOtpVerified: false,
        verifiedCitizen: () => null,
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

  /// Step 2: Verify Fayda OTP to prove real citizen identity (one-time e-KYC verification)
  Future<bool> verifyFaydaCitizenOtp(String otp) async {
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
      final citizen = await _repository.verifyFaydaCitizenOtp(
        faydaId: fin,
        otp: otp,
        txnId: txnId,
      );

      state = state.copyWith(
        isLoading: false,
        isOtpSent: false,
        isFaydaOtpVerified: true,
        verifiedCitizen: () => citizen,
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

  /// Step 3: Password Creation (Local Database)
  /// Saves verified Fayda profile details and hashed password directly into database
  Future<bool> registerWithPassword(String password) async {
    final citizen = state.verifiedCitizen;
    final fin = state.faydaId ?? citizen?.fin;

    if (fin == null || fin.isEmpty) {
      state = state.copyWith(
        errorMessage: () => 'Fayda verification expired. Please verify your National ID again.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final user = await _repository.registerWithPassword(
        fullName: citizen?.fullName ?? 'Ethiopian Citizen',
        phoneNumber: citizen?.phone ?? '+251911000000',
        faydaId: fin,
        password: password,
      );

      state = state.copyWith(
        user: () => user,
        isLoading: false,
        isOtpSent: false,
        isFaydaOtpVerified: false,
        verifiedCitizen: () => null,
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

  /// Subsequent Logins: Password-based authentication against application database
  /// Requires internet connection when entering password
  Future<bool> signInWithPassword({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final user = await _repository.signInWithPassword(
        identifier: identifier,
        password: password,
      );
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

  /// Reset OTP and Registration flow back to entering Fayda ID
  void resetOtpFlow() {
    state = state.copyWith(
      isOtpSent: false,
      isFaydaOtpVerified: false,
      verifiedCitizen: () => null,
      txnId: () => null,
      maskedPhone: () => null,
      mockOtpHint: () => null,
      errorMessage: () => null,
    );
  }

  /// Sets authenticated session from email login or registration completion response.
  Future<void> setSessionFromAuthResponse(Map<String, dynamic> responseData) async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final user = await _repository.setSessionFromAuthResponse(responseData);
      state = state.copyWith(
        user: () => user,
        isLoading: false,
        errorMessage: () => null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Legacy signIn fallback
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    return signInWithPassword(identifier: email, password: password);
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

  Future<void> switchActiveIdir(UserMembership membership) async {
    final current = state.user;
    if (current == null) return;
    final updated = current.copyWith(
      idirId: membership.idirId,
      idirName: membership.idirName,
      role: membership.role,
      memberId: membership.memberNumber,
    );
    state = state.copyWith(user: () => updated);
    await _repository.updateProfile(updated);
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
