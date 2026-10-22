import 'package:flutter_test/flutter_test.dart';

import 'package:idir_app/features/elections/domain/models/election_model.dart';
import 'package:idir_app/features/elections/domain/models/nomination_model.dart';
import 'package:idir_app/features/elections/domain/models/vote_receipt_model.dart';
import 'package:idir_app/features/elections/domain/models/election_results_model.dart';
import 'package:idir_app/features/elections/domain/models/leadership_events_model.dart';
import 'package:idir_app/features/elections/data/elections_repository.dart';
import 'package:idir_app/features/elections/presentation/providers/elections_provider.dart';

class MockResultsElectionsRepository implements ElectionsRepository {
  ElectionResultsModel? mockResults;
  final List<ElectionDisputeModel> mockDisputes = [];
  bool simulateFailure = false;
  String failureMessage = 'Backend error';
  bool certifyCalled = false;
  String? lastRunoffRole;

  @override
  Future<ElectionResultsModel> tallyVotes({
    required String idirId,
    required String electionId,
    bool force = false,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    return mockResults ??
        ElectionResultsModel(
          electionId: electionId,
          electionTitle: '2026 Executive Committee Election',
          status: 'PUBLISHED',
          votingMethod: 'SIMPLE_MAJORITY',
          ballotType: 'SECRET',
          termLengthMonths: 12,
          totalEligibleMembers: 100,
          uniqueVotersCount: 65,
          turnoutPercentage: 65.0,
          quorumPercentage: 50.0,
          quorumReached: true,
          isDisputeWindowOpen: true,
          hoursRemaining: 48.0,
          pendingDisputesCount: 0,
          isCertified: false,
          roles: const [],
        );
  }

  @override
  Future<ElectionResultsModel> getResults({
    required String idirId,
    required String electionId,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    return mockResults ??
        ElectionResultsModel(
          electionId: electionId,
          electionTitle: '2026 Executive Committee Election',
          status: 'PUBLISHED',
          votingMethod: 'SIMPLE_MAJORITY',
          ballotType: 'SECRET',
          termLengthMonths: 12,
          totalEligibleMembers: 100,
          uniqueVotersCount: 65,
          turnoutPercentage: 65.0,
          quorumPercentage: 50.0,
          quorumReached: true,
          isDisputeWindowOpen: true,
          hoursRemaining: 48.0,
          pendingDisputesCount: 0,
          isCertified: false,
          roles: const [],
        );
  }

  @override
  Future<ElectionDisputeModel> fileDispute({
    required String idirId,
    required String electionId,
    required String reason,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    final dispute = ElectionDisputeModel(
      id: 'disp-${mockDisputes.length + 1}',
      electionId: electionId,
      filedByMembershipId: 'mbr-actor-1',
      filerName: 'Dawit Bekele',
      reason: reason,
      status: 'PENDING',
      createdAt: DateTime.now(),
    );
    mockDisputes.add(dispute);
    return dispute;
  }

  @override
  Future<List<ElectionDisputeModel>> listDisputes({
    required String idirId,
    required String electionId,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    return mockDisputes;
  }

  @override
  Future<ElectionDisputeModel> resolveDispute({
    required String idirId,
    required String electionId,
    required String disputeId,
    required String action,
    required String resolution,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    final idx = mockDisputes.indexWhere((d) => d.id == disputeId);
    final updated = ElectionDisputeModel(
      id: disputeId,
      electionId: electionId,
      filedByMembershipId: 'mbr-actor-1',
      filerName: 'Dawit Bekele',
      reason: idx >= 0 ? mockDisputes[idx].reason : 'Grounds for complaint',
      status: action == 'RESOLVE' ? 'RESOLVED' : 'DISMISSED',
      resolution: resolution,
      resolvedAt: DateTime.now(),
      createdAt: idx >= 0 ? mockDisputes[idx].createdAt : DateTime.now(),
    );
    if (idx >= 0) {
      mockDisputes[idx] = updated;
    } else {
      mockDisputes.add(updated);
    }
    return updated;
  }

  @override
  Future<Map<String, dynamic>> certifyElection({
    required String idirId,
    required String electionId,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    certifyCalled = true;
    return {
      'status': 'CERTIFIED',
      'certifiedAt': DateTime.now().toIso8601String(),
      'transferredRoles': [
        {'role': 'CHAIRPERSON', 'winnerMembershipId': 'mbr-winner-1'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> triggerRunoff({
    required String idirId,
    required String electionId,
    required String role,
    DateTime? runoffEndDate,
  }) async {
    if (simulateFailure) throw Exception(failureMessage);
    lastRunoffRole = role;
    return {
      'status': 'RUNOFF',
      'role': role,
      'runoffEndDate': (runoffEndDate ?? DateTime.now().add(const Duration(hours: 48))).toIso8601String(),
    };
  }

  // Task 1-3 stubs
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
  Future<NoConfidenceVoteModel> initiateNoConfidence({
    required String idirId,
    required String targetMembershipId,
    required String targetRole,
    required String reason,
    double thresholdPercentage = 66.67,
    double quorumPercentage = 50.0,
    int durationDays = 7,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<NoConfidenceVoteModel>> listNoConfidenceVotes({
    required String idirId,
  }) =>
      throw UnimplementedError();

  @override
  Future<NoConfidenceVoteModel> getNoConfidenceVote({
    required String idirId,
    required String voteId,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> castNoConfidenceVote({
    required String idirId,
    required String voteId,
    required String choice,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> resolveNoConfidenceVote({
    required String idirId,
    required String voteId,
    bool force = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<LeadershipVacancyModel>> getLeadershipVacancies({
    required String idirId,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> appointTemporaryOfficer({
    required String idirId,
    required String vacantRole,
    required String appointeeMembershipId,
    String? reason,
    int termMonths = 6,
  }) =>
      throw UnimplementedError();

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
  }) =>
      throw UnimplementedError();
}

void main() {
  group('Task 4: Count, Results, and Dispute Window - Frontend Unit Tests', () {
    late MockResultsElectionsRepository repo;
    late ResultsActionNotifier notifier;

    setUp(() {
      repo = MockResultsElectionsRepository();
      notifier = ResultsActionNotifier(repo);
    });

    group('Model Parsing & Business Rules', () {
      test('ElectionResultsModel parses successful election with quorum and clear winner', () {
        final now = DateTime.now();
        final disputeDeadline = now.add(const Duration(hours: 48));

        final json = {
          'electionId': 'elec-task4-1',
          'electionTitle': '2026 Executive Committee Election',
          'status': 'PUBLISHED',
          'votingMethod': 'SIMPLE_MAJORITY',
          'ballotType': 'SECRET',
          'termLengthMonths': 24,
          'isCertified': false,
          'quorumPercentage': 50.0,
          'totalEligibleMembers': 20,
          'uniqueVotersCount': 12,
          'turnoutPercentage': 60.0,
          'quorumReached': true,
          'disputeWindowEndsAt': disputeDeadline.toIso8601String(),
          'isDisputeWindowOpen': true,
          'hoursRemaining': 48.0,
          'pendingDisputesCount': 0,
          'roles': [
            {
              'role': 'CHAIRPERSON',
              'totalVotesCast': 12,
              'votesReceived': 12,
              'isTie': false,
              'winnerNominationId': 'nom-c1',
              'winnerName': 'Abebe Bikila',
              'candidates': [
                {
                  'nominationId': 'nom-c1',
                  'nomineeMembershipId': 'mbr-c1',
                  'nomineeName': 'Abebe Bikila',
                  'votes': 8,
                  'percentage': 66.67,
                },
                {
                  'nominationId': 'nom-c2',
                  'nomineeMembershipId': 'mbr-c2',
                  'nomineeName': 'Almaz Ayana',
                  'votes': 4,
                  'percentage': 33.33,
                },
              ],
            },
          ],
        };

        final results = ElectionResultsModel.fromMap(json);

        expect(results.electionId, 'elec-task4-1');
        expect(results.quorumReached, isTrue);
        expect(results.turnoutPercentage, 60.0);
        expect(results.canCertify, isTrue);
        expect(results.isCertified, isFalse);
        expect(results.isDisputeWindowOpen, isTrue);
        expect(results.roles.length, 1);

        final chairRole = results.roles.first;
        expect(chairRole.role, 'CHAIRPERSON');
        expect(chairRole.hasWinner, isTrue);
        expect(chairRole.isTie, isFalse);
        expect(chairRole.winnerName, 'Abebe Bikila');
        expect(chairRole.candidates.length, 2);
        expect(chairRole.candidates.first.votes, 8);
      });

      test('Quorum failure invalidates certification eligibility', () {
        final json = {
          'electionId': 'elec-task4-failed-quorum',
          'electionTitle': 'Invalid Turnout Election',
          'status': 'CANCELLED',
          'votingMethod': 'SIMPLE_MAJORITY',
          'ballotType': 'SECRET',
          'termLengthMonths': 12,
          'isCertified': false,
          'quorumPercentage': 60.0,
          'totalEligibleMembers': 100,
          'uniqueVotersCount': 30,
          'turnoutPercentage': 30.0,
          'quorumReached': false,
          'isDisputeWindowOpen': false,
          'hoursRemaining': 0.0,
          'pendingDisputesCount': 0,
          'roles': [],
        };

        final results = ElectionResultsModel.fromMap(json);

        expect(results.quorumReached, isFalse);
        expect(results.canCertify, isFalse);
        expect(results.status, 'CANCELLED');
        expect(results.turnoutPercentage, lessThan(results.quorumPercentage));
      });

      test('Tie detection correctly flags isTie and disables canCertify', () {
        final json = {
          'electionId': 'elec-task4-tie',
          'electionTitle': 'Tied Election',
          'status': 'PUBLISHED',
          'votingMethod': 'SIMPLE_MAJORITY',
          'ballotType': 'SECRET',
          'termLengthMonths': 12,
          'isCertified': false,
          'quorumPercentage': 50.0,
          'totalEligibleMembers': 10,
          'uniqueVotersCount': 8,
          'turnoutPercentage': 80.0,
          'quorumReached': true,
          'isDisputeWindowOpen': true,
          'hoursRemaining': 24.0,
          'pendingDisputesCount': 0,
          'roles': [
            {
              'role': 'TREASURER',
              'totalVotesCast': 8,
              'votesReceived': 8,
              'isTie': true,
              'winnerNominationId': null,
              'candidates': [
                {
                  'nominationId': 'nom-t1',
                  'nomineeMembershipId': 'mbr-t1',
                  'nomineeName': 'Candidate 1',
                  'votes': 4,
                  'percentage': 50.0,
                },
                {
                  'nominationId': 'nom-t2',
                  'nomineeMembershipId': 'mbr-t2',
                  'nomineeName': 'Candidate 2',
                  'votes': 4,
                  'percentage': 50.0,
                },
              ],
            },
          ],
        };

        final results = ElectionResultsModel.fromMap(json);

        expect(results.quorumReached, isTrue);
        expect(results.canCertify, isFalse); // Can't certify when tied
        expect(results.roles.first.isTie, isTrue);
        expect(results.roles.first.hasWinner, isFalse);
      });

      test('ElectionDisputeModel properly tracks dispute lifecycle status', () {
        final now = DateTime.now();
        final pendingJson = {
          'id': 'disp-001',
          'electionId': 'elec-001',
          'filedByMembershipId': 'mbr-001',
          'filerName': 'Kebede Michael',
          'reason': 'Voter intimidation observed during offline caucus.',
          'status': 'PENDING',
          'createdAt': now.toIso8601String(),
        };

        final pendingDispute = ElectionDisputeModel.fromMap(pendingJson);
        expect(pendingDispute.isPending, isTrue);
        expect(pendingDispute.isResolved, isFalse);
        expect(pendingDispute.isDismissed, isFalse);

        final resolvedDispute = pendingDispute.copyWith(
          status: 'RESOLVED',
          resolution: 'Committee conducted recounting and validated ballots.',
          resolvedAt: now.add(const Duration(hours: 3)),
        );
        expect(resolvedDispute.isPending, isFalse);
        expect(resolvedDispute.isResolved, isTrue);
        expect(resolvedDispute.resolution, contains('recounting'));

        final dismissedDispute = pendingDispute.copyWith(
          status: 'DISMISSED',
          resolution: 'Allegations lacked substantive evidence.',
        );
        expect(dismissedDispute.isPending, isFalse);
        expect(dismissedDispute.isDismissed, isTrue);
      });
    });

    group('ResultsActionNotifier Action Execution', () {
      test('tallyVotes updates state and succeeds', () async {
        final success = await notifier.tallyVotes(
          idirId: 'idir-001',
          electionId: 'elec-001',
          force: true,
        );

        expect(success, isTrue);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.errorMessage, isNull);
      });

      test('tallyVotes records error when repository fails', () async {
        repo.simulateFailure = true;
        repo.failureMessage = 'Voting window has not ended yet.';

        final success = await notifier.tallyVotes(
          idirId: 'idir-001',
          electionId: 'elec-001',
        );

        expect(success, isFalse);
        expect(notifier.state.errorMessage, contains('Voting window has not ended yet.'));
      });

      test('fileDispute adds dispute and stores lastDispute in state', () async {
        final success = await notifier.fileDispute(
          idirId: 'idir-001',
          electionId: 'elec-001',
          reason: 'Irregularity in secret ballot tally count for Secretary role.',
        );

        expect(success, isTrue);
        expect(notifier.state.lastDispute, isNotNull);
        expect(notifier.state.lastDispute!.reason, contains('Irregularity'));
        expect(repo.mockDisputes.length, 1);
      });

      test('fileDispute fails with clean error message when server rejects', () async {
        repo.simulateFailure = true;
        repo.failureMessage = 'Dispute window has already expired.';

        final success = await notifier.fileDispute(
          idirId: 'idir-001',
          electionId: 'elec-001',
          reason: 'Tardy complaint after dispute window passed.',
        );

        expect(success, isFalse);
        expect(notifier.state.errorMessage, contains('Dispute window has already expired.'));
      });

      test('resolveDispute updates dispute status to RESOLVED', () async {
        final success = await notifier.resolveDispute(
          idirId: 'idir-001',
          electionId: 'elec-001',
          disputeId: 'disp-001',
          action: 'RESOLVE',
          resolution: 'Complaint upheld; vote recount audited by neutral committee.',
        );

        expect(success, isTrue);
        expect(notifier.state.lastDispute!.status, 'RESOLVED');
      });

      test('resolveDispute updates dispute status to DISMISSED', () async {
        final success = await notifier.resolveDispute(
          idirId: 'idir-001',
          electionId: 'elec-001',
          disputeId: 'disp-002',
          action: 'DISMISS',
          resolution: 'Insufficient corroborating testimony.',
        );

        expect(success, isTrue);
        expect(notifier.state.lastDispute!.status, 'DISMISSED');
      });

      test('certifyElection executes handover of leadership roles', () async {
        final success = await notifier.certifyElection(
          idirId: 'idir-001',
          electionId: 'elec-001',
        );

        expect(success, isTrue);
        expect(repo.certifyCalled, isTrue);
        expect(notifier.state.errorMessage, isNull);
      });

      test('certifyElection fails when pending disputes or ties remain', () async {
        repo.simulateFailure = true;
        repo.failureMessage = 'Cannot certify election: 1 dispute(s) still pending adjudication.';

        final success = await notifier.certifyElection(
          idirId: 'idir-001',
          electionId: 'elec-001',
        );

        expect(success, isFalse);
        expect(notifier.state.errorMessage, contains('1 dispute(s) still pending'));
      });

      test('triggerRunoff successfully initiates run-off for tied role', () async {
        final success = await notifier.triggerRunoff(
          idirId: 'idir-001',
          electionId: 'elec-001',
          role: 'TREASURER',
        );

        expect(success, isTrue);
        expect(repo.lastRunoffRole, 'TREASURER');
      });
    });
  });
}
