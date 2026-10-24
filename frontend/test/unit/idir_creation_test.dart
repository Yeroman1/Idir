import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:idir_app/features/idirs/data/idirs_repository.dart';
import 'package:idir_app/features/idirs/domain/models/idir_model.dart';
import 'package:idir_app/features/idirs/presentation/providers/idir_creation_provider.dart';

class MockIdirsRepository implements IdirsRepository {
  IdirModel? latestCreated;

  @override
  Future<IdirModel> createDraftIdir({
    required String name,
    required String community,
    required String location,
    required String purpose,
    required double contributionAmount,
    required String contributionFrequency,
    String? status,
  }) async {
    final model = IdirModel(
      id: 'mock-idir-draft-id',
      name: name,
      community: community,
      location: location,
      purpose: purpose,
      contributionAmount: contributionAmount,
      contributionFrequency: contributionFrequency,
      status: 'DRAFT', // Always DRAFT
      createdAt: DateTime.now(),
    );
    latestCreated = model;
    return model;
  }

  @override
  Future<List<IdirModel>> getUserIdirs() async {
    return latestCreated != null ? [latestCreated!] : [];
  }

  @override
  Future<IdirModel?> getLatestDraft() async {
    return latestCreated;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('IdirModel Unit Tests', () {
    test('IdirModel correctly deserializes and identifies DRAFT status', () {
      final map = {
        'id': 'idir-101',
        'name': 'Bole Medhanealem Idir',
        'community': 'Bole Subcity',
        'location': 'Addis Ababa',
        'purpose': 'Community mutual aid and funeral coverage',
        'contributionAmount': '350.00',
        'contributionFrequency': 'MONTHLY',
        'status': 'DRAFT',
      };

      final idir = IdirModel.fromMap(map);
      expect(idir.id, 'idir-101');
      expect(idir.name, 'Bole Medhanealem Idir');
      expect(idir.community, 'Bole Subcity');
      expect(idir.location, 'Addis Ababa');
      expect(idir.purpose, 'Community mutual aid and funeral coverage');
      expect(idir.contributionAmount, 350.00);
      expect(idir.contributionFrequency, 'MONTHLY');
      expect(idir.status, 'DRAFT');
      expect(idir.isDraft, isTrue);
    });

    test('CreateIdirNotifier rejects invalid and missing fields with per-field errors', () async {
      final mockRepo = MockIdirsRepository();
      final container = ProviderContainer(
        overrides: [
          idirsRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(createIdirNotifierProvider.notifier);

      // Attempt to submit with invalid empty values
      final success = await notifier.submit(
        name: 'A', // Too short (< 2)
        community: '', // Empty (< 2)
        location: '', // Empty (< 2)
        purpose: 'Tiny', // Too short (< 5)
        contributionAmount: -10, // Non-positive (<= 0)
        contributionFrequency: 'INVALID_FREQ',
      );

      expect(success, isFalse);
      final state = container.read(createIdirNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.fieldErrors.containsKey('name'), isTrue);
      expect(state.fieldErrors.containsKey('community'), isTrue);
      expect(state.fieldErrors.containsKey('location'), isTrue);
      expect(state.fieldErrors.containsKey('purpose'), isTrue);
      expect(state.fieldErrors.containsKey('contributionAmount'), isTrue);
      expect(state.fieldErrors.containsKey('contributionFrequency'), isTrue);
    });

    test('CreateIdirNotifier submits valid request, saves as DRAFT, and updates dashboard draft state', () async {
      final mockRepo = MockIdirsRepository();
      final container = ProviderContainer(
        overrides: [
          idirsRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(createIdirNotifierProvider.notifier);

      final success = await notifier.submit(
        name: 'Arada Ras Makonnen Idir',
        community: 'Arada Subcity, Kebele 02',
        location: 'Addis Ababa',
        purpose: 'Mutual assistance, funeral welfare and medical emergencies',
        contributionAmount: 500,
        contributionFrequency: 'MONTHLY',
        clientStatus: 'ACTIVE', // Should be ignored and saved as DRAFT
      );

      expect(success, isTrue);
      final state = container.read(createIdirNotifierProvider);
      expect(state.createdIdir, isNotNull);
      expect(state.createdIdir!.status, 'DRAFT');
      expect(state.createdIdir!.name, 'Arada Ras Makonnen Idir');

      // Verify the userDraftIdirProvider was updated
      final dashboardDraft = container.read(userDraftIdirProvider).value;
      expect(dashboardDraft, isNotNull);
      expect(dashboardDraft!.name, 'Arada Ras Makonnen Idir');
      expect(dashboardDraft.status, 'DRAFT');
      expect(dashboardDraft.isDraft, isTrue);
    });
  });
}
