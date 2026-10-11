import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/providers/pin_provider.dart';
import '../../data/auth_repository.dart';

class AuthState extends Equatable {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isInitialized = false,
  });

  final AppUser? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isInitialized;

  bool get isAuthenticated => user != null;
  UserRole? get role => user?.role;

  AuthState copyWith({
    AppUser? Function()? user,
    bool? isLoading,
    String? Function()? errorMessage,
    bool? isInitialized,
  }) {
    return AuthState(
      user: user != null ? user() : this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  @override
  List<Object?> get props => [user, isLoading, errorMessage, isInitialized];
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
  }

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
