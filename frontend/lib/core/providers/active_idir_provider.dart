import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/app_user.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/idirs/data/idirs_repository.dart';


/// State of available Idirs and the currently active Idir.
class ActiveIdirState extends Equatable {
  const ActiveIdirState({
    this.availableIdirs = const [],
    this.activeIdir,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<UserMembership> availableIdirs;
  final UserMembership? activeIdir;
  final bool isLoading;
  final String? errorMessage;

  ActiveIdirState copyWith({
    List<UserMembership>? availableIdirs,
    UserMembership? Function()? activeIdir,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return ActiveIdirState(
      availableIdirs: availableIdirs ?? this.availableIdirs,
      activeIdir: activeIdir != null ? activeIdir() : this.activeIdir,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        availableIdirs,
        activeIdir,
        isLoading,
        errorMessage,
      ];
}

class ActiveIdirNotifier extends StateNotifier<ActiveIdirState> {
  ActiveIdirNotifier(this._ref)
      : super(const ActiveIdirState(
          availableIdirs: [],
          activeIdir: null,
          isLoading: false,
        )) {
    _init();
    _ref.listen<AppUser?>(currentUserProvider, (prev, next) {
      if (prev != next) {
        reloadIdirs();
      }
    });
  }

  final Ref _ref;
  static const _customIdirsCacheKey = 'custom_cached_user_idirs';

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(AppConstants.prefActiveIdirId) ==
          '00000000-0000-0000-0000-000000000001') {
        await prefs.remove(AppConstants.prefActiveIdirId);
      }
      final customRaw = prefs.getString(_customIdirsCacheKey);
      if (customRaw != null &&
          customRaw.contains('00000000-0000-0000-0000-000000000001')) {
        await prefs.remove(_customIdirsCacheKey);
      }
      // Clean up old demo caches
      final oldKeys = prefs.getKeys().where((k) =>
          k.contains('00000000-0000-0000-0000-000000000001') ||
          k == 'idir_cache_cache_contributions' ||
          k == 'idir_cache_cache_claims' ||
          k == 'idir_cache_cache_expenses' ||
          k == 'idir_cache_cache_members');
      for (final k in oldKeys.toList()) {
        await prefs.remove(k);
      }
    } catch (_) {}
    await reloadIdirs();
  }

  /// Reloads all user memberships & Idirs from local and remote sources.
  Future<void> reloadIdirs() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedActiveIdirId = prefs.getString(AppConstants.prefActiveIdirId);

      // 1. Collect memberships from current user
      final user = _ref.read(currentUserProvider);
      final list = <UserMembership>[];
      final seenIds = <String>{};

      void addMembership(UserMembership m) {
        if (m.idirId.isNotEmpty &&
            m.idirId != '00000000-0000-0000-0000-000000000001' &&
            !seenIds.contains(m.idirId)) {
          seenIds.add(m.idirId);
          list.add(m);
        }
      }

      // Add user memberships from profile
      if (user?.memberships != null) {
        for (final m in user!.memberships) {
          addMembership(m);
        }
      }

      // 2. Load custom / local cached Idirs
      final customRaw = prefs.getString(_customIdirsCacheKey);
      if (customRaw != null && customRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(customRaw) as List<dynamic>;
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final membership = UserMembership.fromMap(item);
              if (membership.idirId != '00000000-0000-0000-0000-000000000001') {
                addMembership(membership);
              }
            }
          }
        } catch (_) {}
      }

      // 3. Load user Idirs from IdirsRepository (including created drafts)
      try {
        final idirsRepo = _ref.read(idirsRepositoryProvider);
        final fetchedIdirs = await idirsRepo.getUserIdirs();
        for (final idir in fetchedIdirs) {
          if (idir.id != '00000000-0000-0000-0000-000000000001') {
            addMembership(
              UserMembership(
                id: idir.id,
                idirId: idir.id,
                idirName: idir.name,
                role: UserRole.chairperson,
                memberNumber: 'CREATOR-01',
                status: idir.status,
                community: idir.community,
                location: idir.location,
                contributionAmount: idir.contributionAmount,
                contributionFrequency: idir.contributionFrequency,
              ),
            );
          }
        }
      } catch (_) {}

      // 4. No fake demo Idirs in real application

      // 5. Select active Idir
      UserMembership? active;
      if (savedActiveIdirId != null &&
          savedActiveIdirId != '00000000-0000-0000-0000-000000000001') {
        active = list.where((m) => m.idirId == savedActiveIdirId).firstOrNull;
      }
      if (active == null &&
          user?.idirId != null &&
          user!.idirId!.isNotEmpty &&
          user!.idirId != '00000000-0000-0000-0000-000000000001') {
        active = list.where((m) => m.idirId == user!.idirId).firstOrNull;
      }
      active ??= list.where((m) => m.idirId != '00000000-0000-0000-0000-000000000001').firstOrNull;
      active ??= list.isNotEmpty ? list.first : null;

      if (active != null) {
        await prefs.setString(AppConstants.prefActiveIdirId, active.idirId);
      } else {
        await prefs.setString(AppConstants.prefActiveIdirId, AppConstants.defaultIdirId);
      }

      if (!mounted) return;
      state = ActiveIdirState(
        availableIdirs: list,
        activeIdir: active,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[ActiveIdirNotifier] Error initializing: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: () => e.toString(),
        );
      }
    }
  }

  /// Switches active Idir instantly, updating persistent storage and AppUser.
  Future<bool> switchIdir(String idirId) async {
    final target = state.availableIdirs.where((m) => m.idirId == idirId).firstOrNull;
    if (target == null) return false;

    if (state.activeIdir?.idirId == idirId) {
      return true; // Already active
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefActiveIdirId, target.idirId);

      if (!mounted) return false;
      state = state.copyWith(activeIdir: () => target);

      // Sync user profile state if auth is initialized and user is logged in
      if (_ref.exists(authNotifierProvider)) {
        final user = _ref.read(authNotifierProvider).user;
        if (user != null) {
          try {
            final authNotifier = _ref.read(authNotifierProvider.notifier);
            await authNotifier.switchActiveIdir(target);
          } catch (_) {}
        }
      }

      return true;
    } catch (e) {
      debugPrint('[ActiveIdirNotifier] Error switching Idir: $e');
      return false;
    }
  }

  /// Adds a newly created or joined Idir and activates it immediately.
  Future<void> addAndSwitchIdir(UserMembership membership) async {
    final updated = List<UserMembership>.from(state.availableIdirs);
    final existingIndex = updated.indexWhere((m) => m.idirId == membership.idirId);
    if (existingIndex != -1) {
      updated[existingIndex] = membership;
    } else {
      updated.insert(0, membership);
    }

    // Persist custom idir locally
    try {
      final prefs = await SharedPreferences.getInstance();
      final customList = updated.map((m) => m.toMap()).toList();
      await prefs.setString(_customIdirsCacheKey, jsonEncode(customList));
      await prefs.setString(AppConstants.prefActiveIdirId, membership.idirId);
    } catch (_) {}

    if (!mounted) return;
    state = state.copyWith(
      availableIdirs: updated,
      activeIdir: () => membership,
    );

    if (_ref.exists(authNotifierProvider)) {
      final user = _ref.read(authNotifierProvider).user;
      if (user != null) {
        try {
          final authNotifier = _ref.read(authNotifierProvider.notifier);
          await authNotifier.switchActiveIdir(membership);
        } catch (_) {}
      }
    }
  }


}

/// Provider managing active Idir and list of user memberships.
final activeIdirProvider =
    StateNotifierProvider<ActiveIdirNotifier, ActiveIdirState>((ref) {
  return ActiveIdirNotifier(ref);
});

/// Current active Idir domain object.
final currentActiveIdirProvider = Provider<UserMembership?>((ref) {
  return ref.watch(activeIdirProvider).activeIdir;
});

/// Current active Idir ID string helper.
final activeIdirIdProvider = Provider<String?>((ref) {
  final active = ref.watch(currentActiveIdirProvider)?.idirId ??
      ref.watch(currentUserProvider)?.idirId;
  if (active != null && active.isNotEmpty && active != '00000000-0000-0000-0000-000000000001') {
    return active;
  }
  return AppConstants.defaultIdirId;
});
