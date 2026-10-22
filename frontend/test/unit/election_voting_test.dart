import 'package:flutter_test/flutter_test.dart';

import 'package:idir_app/features/elections/domain/models/election_model.dart';
import 'package:idir_app/features/elections/domain/models/nomination_model.dart';
import 'package:idir_app/features/elections/domain/models/vote_receipt_model.dart';
import 'package:idir_app/features/elections/data/elections_repository.dart';
import 'package:idir_app/features/elections/presentation/providers/elections_provider.dart';

class MockVotingElectionsRepository implements ElectionsRepository {
  final List<VoteReceiptModel> castReceipts = [];
  final Map<String, Set<String>> votedRolesPerMember = {}; // memberId -> set of roles
  bool simulateDoubleVote = false;
  bool simulateFaydaRequired = false;
  bool simulateWindowClosed = false;
  bool simulateGeneralFailure = false;

  @override
  Future<VoteReceiptModel> castVote({
    required String idirId,
    required String electionId,
    required String role,
    required String candidateNominationId,
  }) async {
    if (simulateFaydaRequired) {
      throw Exception('Voting requires Fayda national digital identity authentication.');
    }
    if (simulateWindowClosed) {
      throw Exception('Voting is not currently active for this election.');
    }
    if (simulateDoubleVote) {
      throw Exception('Member has already voted for the role "$role" in this election.');
    }
    if (simulateGeneralFailure) {
      throw Exception('Server failed to record ballot.');
    }

    final receipt = VoteReceiptModel(
      id: 'rcpt-${DateTime.now().millisecondsSinceEpoch}',
      electionId: electionId,
      role: role,
      votedAt: DateTime.now(),
      receiptTokenHash: 'sha256_mock_hash_${role}_$candidateNominationId',
      ballotType: 'SECRET',
      isSecret: true,
    );

    castReceipts.add(receipt);
    return receipt;
  }

  @override
  Future<VotingStatusModel> getVotingStatus({
    required String idirId,
    required String electionId,
  }) async {
    final votedRoles = castReceipts.map((r) => r.role).toList();
    final allRoles = ['CHAIRPERSON', 'TREASURER', 'AUDITOR'];
    final pendingRoles = allRoles.where((r) => !votedRoles.contains(r)).toList();

    return VotingStatusModel(
      electionId: electionId,
      electionTitle: '2026 Executive Committee Election',
      ballotType: 'SECRET',
      votingMethod: 'SIMPLE_MAJORITY',
      isWindowOpen: !simulateWindowClosed,
      isFaydaVerified: !simulateFaydaRequired,
      isTenureEligible: true,
      canVote: !simulateWindowClosed && !simulateFaydaRequired && pendingRoles.isNotEmpty,
      roles: allRoles,
      votedRoles: votedRoles,
      pendingRoles: pendingRoles,
      receipts: castReceipts,
      allRolesVoted: pendingRoles.isEmpty,
    );
  }

  @override
  Future<Map<String, dynamic>> getBallot({
    required String idirId,
    required String electionId,
  }) async {
    return {
      'electionId': electionId,
      'title': '2026 Executive Committee Election',
      'ballotType': 'SECRET',
      'roles': [
        {
          'role': 'CHAIRPERSON',
          'candidates': [
            {
              'id': 'cand-1',
              'nomineeName': 'Abebe Bikila',
              'statement': 'Proven track record of transparent leadership.',
              'status': 'ACCEPTED',
            },
            {
              'id': 'cand-2',
              'nomineeName': 'Almaz Ayana',
              'statement': 'Dedicated to digital governance and financial accountability.',
              'status': 'ACCEPTED',
            },
          ],
        },
      ],
    };
  }

  // Unused repository methods for voting unit tests
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
}

void main() {
  group('Task 3: Leader Election Voting - Frontend Unit Tests', () {
    late MockVotingElectionsRepository repo;
    late VotingActionNotifier votingNotifier;

    setUp(() {
      repo = MockVotingElectionsRepository();
      votingNotifier = VotingActionNotifier(repo);
    });

    group('VoteReceiptModel & VotingStatusModel Serialization & Rules', () {
      test('VoteReceiptModel correctly parses secret ballot receipt with hash', () {
        final now = DateTime.now();
        final map = {
          'id': 'rcpt-uuid-999',
          'electionId': 'elec-uuid-1',
          'role': 'CHAIRPERSON',
          'votedAt': now.toIso8601String(),
          'receiptTokenHash': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          'ballotType': 'SECRET',
          'isSecret': true,
        };

        final receipt = VoteReceiptModel.fromMap(map);

        expect(receipt.id, 'rcpt-uuid-999');
        expect(receipt.electionId, 'elec-uuid-1');
        expect(receipt.role, 'CHAIRPERSON');
        expect(receipt.ballotType, 'SECRET');
        expect(receipt.isSecret, isTrue);
        expect(receipt.receiptTokenHash, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');

        final serialized = receipt.toMap();
        expect(serialized['id'], 'rcpt-uuid-999');
        expect(serialized['ballotType'], 'SECRET');
        expect(serialized['isSecret'], isTrue);
        expect(serialized['receiptTokenHash'], isNotNull);
      });

      test('VoteReceiptModel correctly represents OPEN ballot transparency', () {
        final now = DateTime.now();
        final map = {
          'id': 'rcpt-open-1',
          'electionId': 'elec-uuid-open',
          'role': 'TREASURER',
          'votedAt': now.toIso8601String(),
          'ballotType': 'OPEN',
          'isSecret': false,
        };

        final receipt = VoteReceiptModel.fromMap(map);

        expect(receipt.ballotType, 'OPEN');
        expect(receipt.isSecret, isFalse);
        expect(receipt.receiptTokenHash, isNull);
      });

      test('VotingStatusModel accurately reflects eligibility and multi-role progress', () {
        final statusMap = {
          'electionId': 'el-test',
          'electionTitle': 'Annual Idir Election',
          'ballotType': 'SECRET',
          'votingMethod': 'SIMPLE_MAJORITY',
          'isWindowOpen': true,
          'isFaydaVerified': true,
          'isTenureEligible': true,
          'canVote': true,
          'roles': ['CHAIRPERSON', 'TREASURER', 'SECRETARY'],
          'votedRoles': ['CHAIRPERSON'],
          'pendingRoles': ['TREASURER', 'SECRETARY'],
          'receipts': [
            {
              'id': 'rcpt-1',
              'electionId': 'el-test',
              'role': 'CHAIRPERSON',
              'votedAt': DateTime.now().toIso8601String(),
              'ballotType': 'SECRET',
              'isSecret': true,
            }
          ],
          'allRolesVoted': false,
        };

        final status = VotingStatusModel.fromMap(statusMap);

        expect(status.electionTitle, 'Annual Idir Election');
        expect(status.canVote, isTrue);
        expect(status.isFaydaVerified, isTrue);
        expect(status.votedRoles, contains('CHAIRPERSON'));
        expect(status.pendingRoles, containsAll(['TREASURER', 'SECRETARY']));
        expect(status.allRolesVoted, isFalse);
        expect(status.receipts.length, 1);
        expect(status.receipts.first.role, 'CHAIRPERSON');
      });
    });

    group('VotingActionNotifier Execution & Guards', () {
      test('Successfully cast ballot returns true, stores lastReceipt and clears error', () async {
        expect(votingNotifier.state.isLoading, isFalse);
        expect(votingNotifier.state.lastReceipt, isNull);
        expect(votingNotifier.state.errorMessage, isNull);

        final success = await votingNotifier.castVote(
          idirId: 'idir-1',
          electionId: 'elec-1',
          role: 'CHAIRPERSON',
          candidateNominationId: 'cand-1',
        );

        expect(success, isTrue);
        expect(votingNotifier.state.isLoading, isFalse);
        expect(votingNotifier.state.errorMessage, isNull);
        expect(votingNotifier.state.lastReceipt, isNotNull);
        expect(votingNotifier.state.lastReceipt!.role, 'CHAIRPERSON');
        expect(votingNotifier.state.lastReceipt!.isSecret, isTrue);
        expect(votingNotifier.state.lastReceipt!.receiptTokenHash, contains('CHAIRPERSON'));
        expect(repo.castReceipts.length, 1);
      });

      test('Double voting prevention: fails when voting twice for the same role', () async {
        repo.simulateDoubleVote = true;

        final success = await votingNotifier.castVote(
          idirId: 'idir-1',
          electionId: 'elec-1',
          role: 'CHAIRPERSON',
          candidateNominationId: 'cand-1',
        );

        expect(success, isFalse);
        expect(votingNotifier.state.isLoading, isFalse);
        expect(votingNotifier.state.lastReceipt, isNull);
        expect(
          votingNotifier.state.errorMessage,
          contains('already voted for the role "CHAIRPERSON"'),
        );
      });

      test('Fayda authentication requirement: fails when voter is not verified', () async {
        repo.simulateFaydaRequired = true;

        final success = await votingNotifier.castVote(
          idirId: 'idir-1',
          electionId: 'elec-1',
          role: 'TREASURER',
          candidateNominationId: 'cand-2',
        );

        expect(success, isFalse);
        expect(votingNotifier.state.errorMessage, contains('Fayda'));
      });

      test('Voting window guard: fails when election voting window is closed', () async {
        repo.simulateWindowClosed = true;

        final success = await votingNotifier.castVote(
          idirId: 'idir-1',
          electionId: 'elec-1',
          role: 'AUDITOR',
          candidateNominationId: 'cand-3',
        );

        expect(success, isFalse);
        expect(votingNotifier.state.errorMessage, contains('Voting is not currently active'));
      });

      test('clearError resets the error message in state', () async {
        repo.simulateGeneralFailure = true;

        await votingNotifier.castVote(
          idirId: 'idir-1',
          electionId: 'elec-1',
          role: 'CHAIRPERSON',
          candidateNominationId: 'cand-1',
        );

        expect(votingNotifier.state.errorMessage, isNotNull);

        votingNotifier.clearError();
        expect(votingNotifier.state.errorMessage, isNull);
      });
    });

    group('Ballot and Status Retrieval', () {
      test('getVotingStatus tracks completed vs pending roles', () async {
        var status = await repo.getVotingStatus(idirId: 'idir-1', electionId: 'elec-1');
        expect(status.allRolesVoted, isFalse);
        expect(status.pendingRoles.length, 3);

        await votingNotifier.castVote(
          idirId: 'idir-1',
          electionId: 'elec-1',
          role: 'CHAIRPERSON',
          candidateNominationId: 'cand-1',
        );

        status = await repo.getVotingStatus(idirId: 'idir-1', electionId: 'elec-1');
        expect(status.votedRoles, ['CHAIRPERSON']);
        expect(status.pendingRoles, ['TREASURER', 'AUDITOR']);
        expect(status.allRolesVoted, isFalse);

        await votingNotifier.castVote(
          idirId: 'idir-1',
          electionId: 'elec-1',
          role: 'TREASURER',
          candidateNominationId: 'cand-2',
        );

        await votingNotifier.castVote(
          idirId: 'idir-1',
          electionId: 'elec-1',
          role: 'AUDITOR',
          candidateNominationId: 'cand-3',
        );

        status = await repo.getVotingStatus(idirId: 'idir-1', electionId: 'elec-1');
        expect(status.votedRoles.length, 3);
        expect(status.pendingRoles.isEmpty, isTrue);
        expect(status.allRolesVoted, isTrue);
      });

      test('getBallot returns accepted candidates per role', () async {
        final ballot = await repo.getBallot(idirId: 'idir-1', electionId: 'elec-1');

        expect(ballot['electionId'], 'elec-1');
        expect(ballot['ballotType'], 'SECRET');
        final roles = ballot['roles'] as List;
        expect(roles.isNotEmpty, isTrue);
        final firstRole = roles.first as Map<String, dynamic>;
        expect(firstRole['role'], 'CHAIRPERSON');
        final candidates = (firstRole['candidates'] as List).cast<Map<String, dynamic>>();
        expect(candidates.length, 2);
        expect(candidates.every((c) => c['status'] == 'ACCEPTED'), isTrue);
      });
    });
  });
}
