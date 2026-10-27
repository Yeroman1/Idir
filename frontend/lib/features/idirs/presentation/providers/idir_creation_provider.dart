import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/idirs_repository.dart';
import '../../domain/models/idir_model.dart';

final userDraftIdirProvider =
    StateNotifierProvider<UserDraftIdirNotifier, AsyncValue<IdirModel?>>((ref) {
  final repo = ref.watch(idirsRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  return UserDraftIdirNotifier(repo, user?.uid);
});

class UserDraftIdirNotifier extends StateNotifier<AsyncValue<IdirModel?>> {
  UserDraftIdirNotifier(this._repo, [this._userId]) : super(const AsyncValue.loading()) {
    if (_userId == null) {
      state = const AsyncValue.data(null);
    } else {
      loadDraft();
    }
  }

  final IdirsRepository _repo;
  final String? _userId;

  Future<void> loadDraft() async {
    if (_userId == null) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      final draft = await _repo.getLatestDraft();
      if (draft != null && draft.createdById != null && draft.createdById != _userId) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.data(draft);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void setDraft(IdirModel draft) {
    if (_userId == null || (draft.createdById != null && draft.createdById != _userId)) {
      return;
    }
    state = AsyncValue.data(draft);
  }
}

class CreateIdirState {
  const CreateIdirState({
    this.isLoading = false,
    this.errorMessage,
    this.fieldErrors = const {},
    this.createdIdir,
  });

  final bool isLoading;
  final String? errorMessage;
  final Map<String, String> fieldErrors;
  final IdirModel? createdIdir;

  CreateIdirState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, String>? fieldErrors,
    IdirModel? createdIdir,
  }) {
    return CreateIdirState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      createdIdir: createdIdir ?? this.createdIdir,
    );
  }
}

class CreateIdirNotifier extends StateNotifier<CreateIdirState> {
  CreateIdirNotifier(this._repo, this._ref) : super(const CreateIdirState());

  final IdirsRepository _repo;
  final Ref _ref;

  Future<bool> submit({
    required String name,
    required String community,
    required String location,
    required String purpose,
    required double contributionAmount,
    required String contributionFrequency,
    String? clientStatus,
  }) async {
    // 1. Client-side pre-validation
    final errors = <String, String>{};
    if (name.trim().length < 2) {
      errors['name'] = 'Idir name must be at least 2 characters';
    }
    if (community.trim().length < 2) {
      errors['community'] = 'Community must be at least 2 characters';
    }
    if (location.trim().length < 2) {
      errors['location'] = 'Location must be at least 2 characters';
    }
    if (purpose.trim().length < 5) {
      errors['purpose'] = 'Purpose must be at least 5 characters';
    }
    if (contributionAmount <= 0) {
      errors['contributionAmount'] =
          'Contribution amount must be greater than 0';
    }
    if (!['WEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY']
        .contains(contributionFrequency)) {
      errors['contributionFrequency'] = 'Please select a valid frequency';
    }

    if (errors.isNotEmpty) {
      state = state.copyWith(
        isLoading: false,
        fieldErrors: errors,
        errorMessage: 'Please fix the required fields',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      fieldErrors: {},
    );

    try {
      final user = _ref.read(currentUserProvider);
      final idir = await _repo.createDraftIdir(
        name: name.trim(),
        community: community.trim(),
        location: location.trim(),
        purpose: purpose.trim(),
        contributionAmount: contributionAmount,
        contributionFrequency: contributionFrequency,
        status: clientStatus,
      );

      final creatorIdir = (idir.createdById == null && user?.uid != null)
          ? IdirModel(
              id: idir.id,
              name: idir.name,
              community: idir.community,
              location: idir.location,
              purpose: idir.purpose,
              contributionAmount: idir.contributionAmount,
              contributionFrequency: idir.contributionFrequency,
              status: idir.status,
              createdById: user!.uid,
              createdAt: idir.createdAt,
              updatedAt: idir.updatedAt,
            )
          : idir;

      _ref.read(userDraftIdirProvider.notifier).setDraft(creatorIdir);
      await _ref.read(activeIdirProvider.notifier).addAndSwitchIdir(
            UserMembership(
              id: creatorIdir.id,
              idirId: creatorIdir.id,
              idirName: creatorIdir.name,
              role: UserRole.chairperson,
              memberNumber: 'CREATOR-01',
              status: creatorIdir.status,
              community: creatorIdir.community,
              location: creatorIdir.location,
              contributionAmount: creatorIdir.contributionAmount,
              contributionFrequency: creatorIdir.contributionFrequency,
            ),
          );
      state = state.copyWith(isLoading: false, createdIdir: creatorIdir);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

final createIdirNotifierProvider =
    StateNotifierProvider.autoDispose<CreateIdirNotifier, CreateIdirState>(
        (ref) {
  final repo = ref.watch(idirsRepositoryProvider);
  return CreateIdirNotifier(repo, ref);
});
