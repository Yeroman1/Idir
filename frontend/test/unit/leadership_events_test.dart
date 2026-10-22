import 'package:flutter_test/flutter_test.dart';

import 'package:idir_app/features/elections/domain/models/election_model.dart';
import 'package:idir_app/features/elections/domain/models/nomination_model.dart';
import 'package:idir_app/features/elections/domain/models/vote_receipt_model.dart';
import 'package:idir_app/features/elections/domain/models/election_results_model.dart';
import 'package:idir_app/features/elections/domain/models/leadership_events_model.dart';
import 'package:idir_app/features/elections/data/elections_repository.dart';
import 'package:idir_app/features/elections/presentation/providers/elections_provider.dart';

class MockLeadershipEventsRepository implements ElectionsRepository {
  bool simulateFailure = false;
  String failureMessage = 'Backend error';

  NoConfidenceVoteModel? mockVote;
  List<LeadershipVacancyModel> mockVacancies = [];
  Map<String, dynamic>? mockResolutionResult;
  ElectionModel? mockByElection;

  @override
  Future<NoConfidenceVoteModel> initiateNoConfidence({
    required String idirId,
    required String targetMembershipId,
    required String targetRole,
    required String reason,
    double thresholdPercentage = 66.67,
    double quorumPercentage = 50.0,
    int durationDays = 7,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    return mockVote ??
        NoConfidenceVoteModel(
          id: 'nc-1',
          idirId: idirId,
          targetMembershipId: targetMembershipId,
          targetRole: targetRole,
          reason: reason,
          thresholdPercentage: thresholdPercentage,
          quorumPercentage: quorumPercentage,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(Duration(days: durationDays)),
          status: 'ACTIVE',
          totalEligibleMembers: 50,
          totalVotesCast: 0,
          supportVotes: 0,
          opposeVotes: 0,
        );
  }

  @override
  Future<List<NoConfidenceVoteModel>> listNoConfidenceVotes({
    required String idirId,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    return mockVote != null ? [mockVote!] : [];
  }

  @override
  Future<NoConfidenceVoteModel> getNoConfidenceVote({
    required String idirId,
    required String voteId,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    return mockVote ??
        NoConfidenceVoteModel(
          id: voteId,
          idirId: idirId,
          targetMembershipId: 'target-mem-1',
          targetRole: 'CHAIRPERSON',
          reason: 'Breach of duties',
          thresholdPercentage: 66.67,
          quorumPercentage: 50.0,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 7)),
          status: 'ACTIVE',
          totalEligibleMembers: 50,
          totalVotesCast: 0,
          supportVotes: 0,
          opposeVotes: 0,
        );
  }

  @override
  Future<Map<String, dynamic>> castNoConfidenceVote({
    required String idirId,
    required String voteId,
    required String choice,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    return {'success': true, 'choice': choice};
  }

  @override
  Future<Map<String, dynamic>> resolveNoConfidenceVote({
    required String idirId,
    required String voteId,
    bool force = false,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    return mockResolutionResult ??
        {
          'success': true,
          'result': {
            'finalStatus': 'PASSED',
            'passed': true,
            'reason': 'Removal threshold met',
            'supportPercentage': 75.0,
          }
        };
  }

  @override
  Future<List<LeadershipVacancyModel>> getLeadershipVacancies({
    required String idirId,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    return mockVacancies;
  }

  @override
  Future<Map<String, dynamic>> appointTemporaryOfficer({
    required String idirId,
    required String vacantRole,
    required String appointeeMembershipId,
    String? reason,
    int termMonths = 6,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    return {'success': true, 'appointedRole': vacantRole};
  }

  @override
  Future<ElectionModel> createByElection({
    required String idirId,
    required String vacantRole,
    String? title,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? nominationStartDate,
    DateTime? nominationEndDate,
    required List<String> committeeMemberIds,
    double quorumPercentage = 50.0,
    int termLengthMonths = 12,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    return mockByElection ??
        ElectionModel(
          id: 'by-elect-1',
          idirId: idirId,
          title: title ?? 'Special By-Election for $vacantRole',
          description: description,
          roles: [vacantRole],
          startDate: startDate,
          endDate: endDate,
          termLengthMonths: termLengthMonths,
          votingMethod: 'SIMPLE_MAJORITY',
          ballotType: 'SECRET',
          quorumPercentage: quorumPercentage,
          status: 'SCHEDULED',
        );
  }

  // --- Stubs for other tasks ---
  @override
  Future<ElectionModel> createElection({
    required String idirId,
    required String title,
    String? description,
    required List<String> roles,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? nominationStartDate,
    DateTime? nominationEndDate,
    required int termLengthMonths,
    required String votingMethod,
    required String ballotType,
    required double quorumPercentage,
    int minMembershipTenureDays = 0,
    bool requiresGoodStanding = true,
    int disputeWindowHours = 48,
    DateTime? handoverDate,
    required List<String> committeeMemberIds,
  }) =>
      throw UnimplementedError();

  @override
  Future<ElectionModel> getElection({
    required String idirId,
    required String electionId,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<ElectionModel>> listElections({
    required String idirId,
    String? status,
  }) =>
      throw UnimplementedError();

  @override
  Future<ElectionModel> updateElection({
    required String idirId,
    required String electionId,
    Map<String, dynamic> updates = const {},
  }) =>
      throw UnimplementedError();

  @override
  Future<void> cancelElection({
    required String idirId,
    required String electionId,
    required String reason,
  }) =>
      throw UnimplementedError();

  @override
  Future<NominationModel> nominateCandidate({
    required String idirId,
    required String electionId,
    required String role,
    required String nomineeMembershipId,
    String? statement,
  }) =>
      throw UnimplementedError();

  @override
  Future<NominationModel> respondToNomination({
    required String idirId,
    required String electionId,
    required String nominationId,
    required String action,
    String? statement,
  }) =>
      throw UnimplementedError();

  @override
  Future<NominationModel> withdrawNomination({
    required String idirId,
    required String electionId,
    required String nominationId,
  }) =>
      throw UnimplementedError();

  @override
  Future<NominationModel> updateCandidateStatement({
    required String idirId,
    required String electionId,
    required String nominationId,
    required String statement,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<NominationModel>> listNominations({
    required String idirId,
    required String electionId,
    String? role,
    String? status,
    bool? ballotOnly,
  }) =>
      throw UnimplementedError();

  @override
  Future<NominationModel> getCandidatePage({
    required String idirId,
    required String electionId,
    required String nominationId,
  }) =>
      throw UnimplementedError();

  @override
  Future<VoteReceiptModel> castVote({
    required String idirId,
    required String electionId,
    required String role,
    required String candidateNominationId,
  }) =>
      throw UnimplementedError();

  @override
  Future<VotingStatusModel> getVotingStatus({
    required String idirId,
    required String electionId,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getBallot({
    required String idirId,
    required String electionId,
  }) =>
      throw UnimplementedError();

  @override
  Future<ElectionResultsModel> tallyVotes({
    required String idirId,
    required String electionId,
    bool force = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<ElectionResultsModel> getResults({
    required String idirId,
    required String electionId,
  }) =>
      throw UnimplementedError();

  @override
  Future<ElectionDisputeModel> fileDispute({
    required String idirId,
    required String electionId,
    required String reason,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<ElectionDisputeModel>> listDisputes({
    required String idirId,
    required String electionId,
  }) =>
      throw UnimplementedError();

  @override
  Future<ElectionDisputeModel> resolveDispute({
    required String idirId,
    required String electionId,
    required String disputeId,
    required String action,
    required String resolution,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> certifyElection({
    required String idirId,
    required String electionId,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> triggerRunoff({
    required String idirId,
    required String electionId,
    required String role,
    DateTime? runoffEndDate,
  }) =>
      throw UnimplementedError();
}

void main() {
  group('Task 5: Leadership Events & Vacancies - Unit Tests', () {
    late MockLeadershipEventsRepository repo;
    late LeadershipEventsActionNotifier notifier;

    setUp(() {
      repo = MockLeadershipEventsRepository();
      notifier = LeadershipEventsActionNotifier(repo);
    });

    group('NoConfidenceVoteModel - Serialization and Computed Rules', () {
      test('correctly parses model from nested JSON map with member and user info', () {
        final json = {
          'id': 'nc-vote-123',
          'idirId': 'idir-1',
          'targetMembershipId': 'mem-target-1',
          'targetRole': 'CHAIRPERSON',
          'targetMembership': {
            'user': {
              'fullName': 'Abebe Bikila',
              'phoneNumber': '+251911223344',
            }
          },
          'initiatedByMembership': {
            'user': {
              'fullName': 'Kebede Michael',
            }
          },
          'reason': 'Mismanagement of community funds and non-attendance',
          'thresholdPercentage': 66.67,
          'quorumPercentage': 50.0,
          'startDate': '2026-10-20T10:00:00Z',
          'endDate': '2026-10-27T10:00:00Z',
          'status': 'ACTIVE',
          'totalEligibleMembers': 100,
          'totalVotesCast': 60,
          'supportVotes': 45,
          'opposeVotes': 15,
          'hasVoted': true,
        };

        final model = NoConfidenceVoteModel.fromMap(json);

        expect(model.id, 'nc-vote-123');
        expect(model.targetName, 'Abebe Bikila');
        expect(model.targetPhone, '+251911223344');
        expect(model.initiatedByName, 'Kebede Michael');
        expect(model.targetRole, 'CHAIRPERSON');
        expect(model.isActive, isTrue);
        expect(model.isPassed, isFalse);
        expect(model.isFailed, isFalse);
        expect(model.hasVoted, isTrue);

        // Turnout = 60 / 100 = 60.0%
        expect(model.turnoutPercentage, 60.0);
        // Quorum reached = 60% >= 50%
        expect(model.quorumReached, isTrue);

        // Support = 45 / 60 = 75.0%
        expect(model.supportPercentage, 75.0);
        // Threshold reached = 75% >= 66.67%
        expect(model.thresholdReached, isTrue);

        final mapped = model.toMap();
        expect(mapped['id'], 'nc-vote-123');
        expect(mapped['targetName'], 'Abebe Bikila');
        expect(mapped['status'], 'ACTIVE');
      });

      test('accurately calculates failure when quorum is missed', () {
        final model = NoConfidenceVoteModel(
          id: 'nc-quorum-fail',
          idirId: 'idir-1',
          targetMembershipId: 'mem-1',
          targetRole: 'TREASURER',
          reason: 'Lack of reports',
          thresholdPercentage: 66.67,
          quorumPercentage: 50.0,
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 8),
          status: 'FAILED_NO_QUORUM',
          totalEligibleMembers: 100,
          totalVotesCast: 30, // 30% < 50% quorum
          supportVotes: 28, // High support, but quorum missed
          opposeVotes: 2,
        );

        expect(model.turnoutPercentage, 30.0);
        expect(model.quorumReached, isFalse);
        expect(model.isFailed, isTrue);
        expect(model.isActive, isFalse);
      });

      test('accurately calculates failure when supermajority threshold is missed', () {
        final model = NoConfidenceVoteModel(
          id: 'nc-threshold-fail',
          idirId: 'idir-1',
          targetMembershipId: 'mem-1',
          targetRole: 'SECRETARY',
          reason: 'Inadequate minutes',
          thresholdPercentage: 66.67,
          quorumPercentage: 50.0,
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 8),
          status: 'FAILED',
          totalEligibleMembers: 100,
          totalVotesCast: 60, // 60% >= 50% quorum met
          supportVotes: 35, // 35 / 60 = 58.33% < 66.67%
          opposeVotes: 25,
        );

        expect(model.quorumReached, isTrue);
        expect(model.supportPercentage, closeTo(58.33, 0.01));
        expect(model.thresholdReached, isFalse);
        expect(model.isFailed, isTrue);
      });
    });

    group('LeadershipVacancyModel - Parsing and Role Status Rules', () {
      test('parses occupied role with nested current holder and term info', () {
        final json = {
          'role': 'CHAIRPERSON',
          'status': 'OCCUPIED',
          'currentHolder': {
            'membershipId': 'mem-chair-1',
            'fullName': 'Almaz Ayana',
            'phoneNumber': '+251922334455',
            'memberNumber': 'MBR-004',
          },
          'term': {
            'status': 'ACTIVE',
            'endDate': '2027-10-22T00:00:00Z',
          },
          'activeNoConfidenceVoteId': 'nc-vote-99',
        };

        final model = LeadershipVacancyModel.fromMap(json);

        expect(model.role, 'CHAIRPERSON');
        expect(model.status, 'OCCUPIED');
        expect(model.isOccupied, isTrue);
        expect(model.isVacant, isFalse);
        expect(model.isInterim, isFalse);
        expect(model.holderName, 'Almaz Ayana');
        expect(model.holderMemberNumber, 'MBR-004');
        expect(model.activeNoConfidenceVoteId, 'nc-vote-99');
        expect(model.termStatus, 'ACTIVE');

        final map = model.toMap();
        expect(map['role'], 'CHAIRPERSON');
        expect(map['status'], 'OCCUPIED');
        expect(map['holderName'], 'Almaz Ayana');
      });

      test('parses vacant role with null holder', () {
        final json = {
          'role': 'TREASURER',
          'status': 'VACANT',
        };

        final model = LeadershipVacancyModel.fromMap(json);

        expect(model.role, 'TREASURER');
        expect(model.status, 'VACANT');
        expect(model.isVacant, isTrue);
        expect(model.isOccupied, isFalse);
        expect(model.isInterim, isFalse);
        expect(model.holderMembershipId, isNull);
        expect(model.holderName, isNull);
      });

      test('parses interim role correctly', () {
        final json = {
          'role': 'AUDITOR',
          'status': 'INTERIM',
          'currentHolder': {
            'membershipId': 'mem-interim-1',
            'fullName': 'Derartu Tulu',
            'phoneNumber': '+251933445566',
          },
          'term': {
            'status': 'INTERIM',
          },
        };

        final model = LeadershipVacancyModel.fromMap(json);

        expect(model.isInterim, isTrue);
        expect(model.isVacant, isFalse);
        expect(model.isOccupied, isFalse);
        expect(model.holderName, 'Derartu Tulu');
      });
    });

    group('LeadershipEventsActionNotifier - Workflows & State Updates', () {
      test('initiateNoConfidence successfully sets lastVote and success message', () async {
        final ok = await notifier.initiateNoConfidence(
          idirId: 'idir-1',
          targetMembershipId: 'target-mem-1',
          targetRole: 'CHAIRPERSON',
          reason: 'Gross negligence',
          thresholdPercentage: 66.67,
          quorumPercentage: 50.0,
          durationDays: 7,
        );

        expect(ok, isTrue);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.errorMessage, isNull);
        expect(notifier.state.lastVote, isNotNull);
        expect(notifier.state.lastVote!.targetRole, 'CHAIRPERSON');
        expect(notifier.state.successMessage, contains('initiated successfully'));
      });

      test('initiateNoConfidence handles failure and sets error message', () async {
        repo.simulateFailure = true;
        repo.failureMessage = 'Active vote already in progress for CHAIRPERSON';

        final ok = await notifier.initiateNoConfidence(
          idirId: 'idir-1',
          targetMembershipId: 'target-mem-1',
          targetRole: 'CHAIRPERSON',
          reason: 'Gross negligence',
        );

        expect(ok, isFalse);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.errorMessage, 'Active vote already in progress for CHAIRPERSON');
        expect(notifier.state.lastVote, isNull);
      });

      test('castNoConfidenceVote successfully records SUPPORT ballot', () async {
        final ok = await notifier.castNoConfidenceVote(
          idirId: 'idir-1',
          voteId: 'nc-vote-1',
          choice: 'SUPPORT',
        );

        expect(ok, isTrue);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.successMessage, contains('securely cast (SUPPORT)'));
      });

      test('castNoConfidenceVote handles duplicate vote rejection', () async {
        repo.simulateFailure = true;
        repo.failureMessage = 'Member has already cast a ballot for this motion.';

        final ok = await notifier.castNoConfidenceVote(
          idirId: 'idir-1',
          voteId: 'nc-vote-1',
          choice: 'OPPOSE',
        );

        expect(ok, isFalse);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.errorMessage, contains('already cast a ballot'));
      });

      test('resolveNoConfidenceVote records removal when vote passed', () async {
        repo.mockResolutionResult = {
          'success': true,
          'result': {
            'passed': true,
            'finalStatus': 'PASSED',
            'supportPercentage': 80.0,
          }
        };

        final ok = await notifier.resolveNoConfidenceVote(
          idirId: 'idir-1',
          voteId: 'nc-vote-1',
        );

        expect(ok, isTrue);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.successMessage, contains('Officer removed and leadership seat vacated'));
      });

      test('resolveNoConfidenceVote records retention when vote fails', () async {
        repo.mockResolutionResult = {
          'success': true,
          'result': {
            'passed': false,
            'finalStatus': 'FAILED',
            'supportPercentage': 40.0,
          }
        };

        final ok = await notifier.resolveNoConfidenceVote(
          idirId: 'idir-1',
          voteId: 'nc-vote-1',
        );

        expect(ok, isTrue);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.successMessage, contains('Officer retained'));
      });

      test('appointTemporaryOfficer succeeds and sets interim message', () async {
        final ok = await notifier.appointTemporaryOfficer(
          idirId: 'idir-1',
          vacantRole: 'TREASURER',
          appointeeMembershipId: 'mem-appointee-1',
          reason: 'Emergency interim appointment',
          termMonths: 6,
        );

        expect(ok, isTrue);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.successMessage, contains('Interim temporary officer appointed for TREASURER'));
      });

      test('appointTemporaryOfficer reports failure if appointee is not in good standing', () async {
        repo.simulateFailure = true;
        repo.failureMessage = 'Appointed member must be an active member in good standing.';

        final ok = await notifier.appointTemporaryOfficer(
          idirId: 'idir-1',
          vacantRole: 'TREASURER',
          appointeeMembershipId: 'mem-appointee-1',
        );

        expect(ok, isFalse);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.errorMessage, contains('active member in good standing'));
      });

      test('createByElection schedules election for vacant seat', () async {
        final ok = await notifier.createByElection(
          idirId: 'idir-1',
          vacantRole: 'SECRETARY',
          title: 'Special By-Election for Secretary',
          description: 'Expedited election following vacancy',
          startDate: DateTime.now().add(const Duration(days: 2)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          committeeMemberIds: ['cm-1', 'cm-2', 'cm-3'],
          quorumPercentage: 50.0,
          termLengthMonths: 12,
        );

        expect(ok, isTrue);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.successMessage, contains('By-election successfully scheduled for SECRETARY'));
      });

      test('createByElection handles failure on validation error', () async {
        repo.simulateFailure = true;
        repo.failureMessage = 'At least 3 committee members required';

        final ok = await notifier.createByElection(
          idirId: 'idir-1',
          vacantRole: 'SECRETARY',
          startDate: DateTime.now().add(const Duration(days: 2)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          committeeMemberIds: ['cm-1'],
        );

        expect(ok, isFalse);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.errorMessage, contains('At least 3 committee members required'));
      });
    });
  });
}

