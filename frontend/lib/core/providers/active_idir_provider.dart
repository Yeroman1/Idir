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
      // Purge legacy un-scoped draft cache and active idir key
      await prefs.remove('cached_draft_idirs');
      final activeGlobal = prefs.getString(AppConstants.prefActiveIdirId);
      if (activeGlobal != null && activeGlobal.startsWith('draft-')) {
        await prefs.remove(AppConstants.prefActiveIdirId);
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

      // 1. Collect memberships from current user
      final user = _ref.read(currentUserProvider);
      if (user == null) {
        if (!mounted) return;
        if (state.availableIdirs.isNotEmpty && state.activeIdir != null) {
          state = state.copyWith(isLoading: false);
          return;
        }
        state = const ActiveIdirState(
          availableIdirs: [],
          activeIdir: null,
          isLoading: false,
        );
        return;
      }

      final userPrefKey = '${AppConstants.prefActiveIdirId}_${user.uid}';
      final savedActiveIdirId = prefs.getString(userPrefKey) ??
          prefs.getString(AppConstants.prefActiveIdirId);

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
      if (user.memberships.isNotEmpty) {
        for (final m in user.memberships) {
          addMembership(m);
        }
      }

      // 2. Load custom / local cached Idirs for this user
      final userCacheKey = '${_customIdirsCacheKey}_${user.uid}';
      final customRaw = prefs.getString(userCacheKey);
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

      // 3. Load user Idirs from IdirsRepository (strictly creator's drafts only)
      try {
        final idirsRepo = _ref.read(idirsRepositoryProvider);
        final fetchedIdirs = await idirsRepo.getUserIdirs();
        for (final idir in fetchedIdirs) {
          if (idir.id != '00000000-0000-0000-0000-000000000001') {
            // Privacy check: draft Idirs only belong to the creator
            if (idir.createdById != null && idir.createdById != user.uid) {
              continue;
            }
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

      // 5. Select active Idir strictly from user's available Idirs, prioritizing real backend Idirs
      final realList = list.where((m) => !m.idirId.startsWith('draft-')).toList();
      final priorityList = realList.isNotEmpty ? realList : list;

      UserMembership? active;
      if (savedActiveIdirId != null &&
          !savedActiveIdirId.startsWith('draft-') &&
          savedActiveIdirId != '00000000-0000-0000-0000-000000000001') {
        active = priorityList.where((m) => m.idirId == savedActiveIdirId).firstOrNull;
      }
      if (active == null &&
          user.idirId != null &&
          user.idirId!.isNotEmpty &&
          !user.idirId!.startsWith('draft-') &&
          user.idirId != '00000000-0000-0000-0000-000000000001') {
        active = priorityList.where((m) => m.idirId == user.idirId).firstOrNull;
      }
      active ??= priorityList.where((m) => m.idirId != '00000000-0000-0000-0000-000000000001').firstOrNull;
      active ??= priorityList.isNotEmpty ? priorityList.first : null;

      if (active != null) {
        await prefs.setString(userPrefKey, active.idirId);
      } else {
        await prefs.remove(userPrefKey);
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
      final user = _ref.read(currentUserProvider);
      final userPrefKey = '${AppConstants.prefActiveIdirId}_${user?.uid ?? "anon"}';
      await prefs.setString(userPrefKey, target.idirId);
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

    // Persist custom idir locally for this user
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _ref.read(currentUserProvider);
      final userCacheKey = '${_customIdirsCacheKey}_${user?.uid ?? "anon"}';
      final userPrefKey = '${AppConstants.prefActiveIdirId}_${user?.uid ?? "anon"}';
      final customList = updated.map((m) => m.toMap()).toList();
      await prefs.setString(userCacheKey, jsonEncode(customList));
      await prefs.setString(userPrefKey, membership.idirId);
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

  /// Isolated test helper strictly for offline unit tests
  void seedForTest() {
    const list = [
      UserMembership(
        id: 'idir_tinsae_001',
        idirId: 'idir_tinsae_001',
        idirName: 'Tinsae Mutual Aid Association',
        role: UserRole.chairperson,
        memberNumber: 'MEM-001',
        status: 'ACTIVE',
        community: 'Kirkos Community',
        location: 'Meskel Flower, Addis Ababa',
        contributionAmount: 50.0,
        contributionFrequency: 'MONTHLY',
      ),
      UserMembership(
        id: AppConstants.defaultIdirId,
        idirId: AppConstants.defaultIdirId,
        idirName: 'Bole Medhanealem Yebego Adragot Idir',
        role: UserRole.member,
        memberNumber: 'BM-042',
        status: 'ACTIVE',
        community: 'Bole Community',
        location: 'Near Medhanealem Cathedral, Addis Ababa',
        contributionAmount: 200.0,
        contributionFrequency: 'MONTHLY',
      ),
    ];
    state = ActiveIdirState(
      availableIdirs: list,
      activeIdir: list.first,
      isLoading: false,
    );
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

/// Current active Idir ID string helper. Returns null if user is not in any Idir.
final activeIdirIdProvider = Provider<String?>((ref) {
  final active = ref.watch(currentActiveIdirProvider)?.idirId ??
      ref.watch(currentUserProvider)?.idirId;
  if (active != null && active.isNotEmpty && active != '00000000-0000-0000-0000-000000000001') {
    return active;
  }
  return null;
});
