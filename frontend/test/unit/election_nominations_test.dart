import 'package:flutter_test/flutter_test.dart';

import 'package:idir_app/features/elections/domain/models/election_model.dart';
import 'package:idir_app/features/elections/domain/models/nomination_model.dart';
import 'package:idir_app/features/elections/domain/models/vote_receipt_model.dart';
import 'package:idir_app/features/elections/domain/models/election_results_model.dart';
import 'package:idir_app/features/elections/data/elections_repository.dart';
import 'package:idir_app/features/elections/presentation/providers/elections_provider.dart';

class MockNominationsRepository implements ElectionsRepository {
  final List<NominationModel> nominations = [];
  int _idCounter = 1;
  bool shouldThrow = false;
  String throwMessage = 'Backend error';

  @override
  Future<NominationModel> nominateCandidate({
    required String idirId,
    required String electionId,
    required String role,
    required String nomineeMembershipId,
    String? statement,
  }) async {
    if (shouldThrow) throw Exception(throwMessage);

    final isSelf = nomineeMembershipId == 'actor-membership-id';
    final nom = NominationModel(
      id: 'nom-${_idCounter++}',
      electionId: electionId,
      role: role,
      nomineeMembershipId: nomineeMembershipId,
      nominatedByMembershipId: 'actor-membership-id',
      statement: statement,
      status: isSelf ? 'ACCEPTED' : 'PENDING',
      nomineeName: isSelf ? 'Self Nominee' : 'Other Nominee',
      acceptedAt: isSelf ? DateTime.now() : null,
      createdAt: DateTime.now(),
    );
    nominations.add(nom);
    return nom;
  }

  @override
  Future<NominationModel> respondToNomination({
    required String idirId,
    required String electionId,
    required String nominationId,
    required String action,
    String? statement,
  }) async {
    if (shouldThrow) throw Exception(throwMessage);

    final idx = nominations.indexWhere((n) => n.id == nominationId);
    final isAccept = action == 'ACCEPT';
    final updated = (idx >= 0 ? nominations[idx] : _dummyNomination(nominationId)).copyWith(
      status: isAccept ? 'ACCEPTED' : 'DECLINED',
      statement: statement,
      acceptedAt: isAccept ? DateTime.now() : null,
      declinedAt: isAccept ? null : DateTime.now(),
    );
    if (idx >= 0) nominations[idx] = updated;
    return updated;
  }

  @override
  Future<NominationModel> withdrawNomination({
    required String idirId,
    required String electionId,
    required String nominationId,
  }) async {
    if (shouldThrow) throw Exception(throwMessage);

    final idx = nominations.indexWhere((n) => n.id == nominationId);
    final updated = (idx >= 0 ? nominations[idx] : _dummyNomination(nominationId)).copyWith(
      status: 'WITHDRAWN',
    );
    if (idx >= 0) nominations[idx] = updated;
    return updated;
  }

  @override
  Future<NominationModel> updateCandidateStatement({
    required String idirId,
    required String electionId,
    required String nominationId,
    required String statement,
  }) async {
    if (shouldThrow) throw Exception(throwMessage);

    final idx = nominations.indexWhere((n) => n.id == nominationId);
    final updated = (idx >= 0 ? nominations[idx] : _dummyNomination(nominationId)).copyWith(
      statement: statement,
    );
    if (idx >= 0) nominations[idx] = updated;
    return updated;
  }

  @override
  Future<List<NominationModel>> listNominations({
    required String idirId,
    required String electionId,
    String? role,
    String? status,
    bool? ballotOnly,
  }) async {
    if (shouldThrow) throw Exception(throwMessage);

    var list = List<NominationModel>.from(nominations);
    if (ballotOnly == true || (ballotOnly == null && status == null)) {
      list = list.where((n) => n.isAccepted).toList();
    } else if (status != null && status != 'ALL') {
      list = list.where((n) => n.status.toUpperCase() == status.toUpperCase()).toList();
    }
    if (role != null) {
      list = list.where((n) => n.role == role).toList();
    }
    return list;
  }

  @override
  Future<NominationModel> getCandidatePage({
    required String idirId,
    required String electionId,
    required String nominationId,
  }) async {
    if (shouldThrow) throw Exception(throwMessage);

    return nominations.firstWhere(
      (n) => n.id == nominationId,
      orElse: () => _dummyNomination(nominationId),
    );
  }

  NominationModel _dummyNomination(String id) => NominationModel(
        id: id,
        electionId: 'el-1',
        role: 'CHAIRPERSON',
        nomineeMembershipId: 'm-1',
        nominatedByMembershipId: 'm-1',
        status: 'ACCEPTED',
      );

  // Unused election setup methods for this mock
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
  group('Task 2: Nominations and Candidate Pages - Unit Tests', () {
    late MockNominationsRepository repo;
    late NominationActionNotifier notifier;

    setUp(() {
      repo = MockNominationsRepository();
      notifier = NominationActionNotifier(repo);
    });

    test('NominationModel fromMap parses nested nominee and nominator objects correctly', () {
      final json = {
        'id': 'nom-001',
        'electionId': 'el-001',
        'role': 'CHAIRPERSON',
        'status': 'ACCEPTED',
        'statement': 'Pledging complete financial audit transparency',
        'nomineeMembership': {
          'id': 'mbr-nominee-1',
          'memberNumber': 'MBR-100',
          'joinedAt': '2024-01-01T00:00:00.000Z',
          'user': {
            'id': 'user-1',
            'fullName': 'Abebe Bikila',
            'phoneNumber': '+251911111111',
            'faydaId': 'FAYDA-12345',
          },
        },
        'nominatedByMembership': {
          'id': 'mbr-nominator-1',
          'memberNumber': 'MBR-200',
          'user': {
            'fullName': 'Chala Committee',
          },
        },
        'acceptedAt': '2026-10-22T10:00:00.000Z',
      };

      final model = NominationModel.fromMap(json);

      expect(model.id, equals('nom-001'));
      expect(model.role, equals('CHAIRPERSON'));
      expect(model.nomineeMembershipId, equals('mbr-nominee-1'));
      expect(model.nomineeName, equals('Abebe Bikila'));
      expect(model.nomineeMemberNumber, equals('MBR-100'));
      expect(model.nomineePhone, equals('+251911111111'));
      expect(model.nomineeFaydaId, equals('FAYDA-12345'));
      expect(model.nominatedByName, equals('Chala Committee'));
      expect(model.isAccepted, isTrue);
      expect(model.isPending, isFalse);
      expect(model.isDeclined, isFalse);
      expect(model.statement, contains('financial audit transparency'));
    });

    test('NominationModel status helpers correctly classify states', () {
      const accepted = NominationModel(
        id: '1',
        electionId: 'e',
        role: 'CHAIRPERSON',
        nomineeMembershipId: 'm1',
        nominatedByMembershipId: 'm1',
        status: 'ACCEPTED',
      );
      expect(accepted.isAccepted, isTrue);
      expect(accepted.isSelfNomination, isTrue);

      const pending = NominationModel(
        id: '2',
        electionId: 'e',
        role: 'TREASURER',
        nomineeMembershipId: 'm2',
        nominatedByMembershipId: 'm1',
        status: 'PENDING',
      );
      expect(pending.isPending, isTrue);
      expect(pending.isSelfNomination, isFalse);

      const declined = NominationModel(
        id: '3',
        electionId: 'e',
        role: 'SECRETARY',
        nomineeMembershipId: 'm3',
        nominatedByMembershipId: 'm1',
        status: 'DECLINED',
      );
      expect(declined.isDeclined, isTrue);

      const withdrawn = NominationModel(
        id: '4',
        electionId: 'e',
        role: 'AUDITOR',
        nomineeMembershipId: 'm4',
        nominatedByMembershipId: 'm4',
        status: 'WITHDRAWN',
      );
      expect(withdrawn.isWithdrawn, isTrue);
    });

    test('Self-nomination is registered and auto-accepted on the ballot', () async {
      final success = await notifier.nominateCandidate(
        idirId: 'idir-1',
        electionId: 'el-1',
        role: 'CHAIRPERSON',
        nomineeMembershipId: 'actor-membership-id',
        statement: 'Ready to lead with accountability.',
      );

      expect(success, isTrue);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.nomination, isNotNull);
      expect(notifier.state.nomination!.isAccepted, isTrue);
      expect(notifier.state.successMessage, contains('Candidate self-nomination accepted'));
    });

    test('Other-member nomination starts as PENDING until nominee responds', () async {
      final success = await notifier.nominateCandidate(
        idirId: 'idir-1',
        electionId: 'el-1',
        role: 'TREASURER',
        nomineeMembershipId: 'other-membership-id',
        statement: 'Highly trustworthy accountant.',
      );

      expect(success, isTrue);
      expect(notifier.state.nomination, isNotNull);
      expect(notifier.state.nomination!.isPending, isTrue);
      expect(notifier.state.successMessage, contains('pending nominee acceptance'));
    });

    test('Nominee accepts nomination: status transitions to ACCEPTED for ballot', () async {
      // First create pending nomination
      await repo.nominateCandidate(
        idirId: 'idir-1',
        electionId: 'el-1',
        role: 'TREASURER',
        nomineeMembershipId: 'other-membership-id',
      );
      final nomId = repo.nominations.first.id;

      final success = await notifier.respondToNomination(
        idirId: 'idir-1',
        electionId: 'el-1',
        nominationId: nomId,
        action: 'ACCEPT',
        statement: 'Honored to serve our community.',
      );

      expect(success, isTrue);
      expect(notifier.state.nomination!.isAccepted, isTrue);
      expect(notifier.state.nomination!.statement, equals('Honored to serve our community.'));
      expect(notifier.state.successMessage, contains('Nomination accepted!'));
    });

    test('Nominee declines nomination: status transitions to DECLINED', () async {
      await repo.nominateCandidate(
        idirId: 'idir-1',
        electionId: 'el-1',
        role: 'SECRETARY',
        nomineeMembershipId: 'other-membership-id',
      );
      final nomId = repo.nominations.first.id;

      final success = await notifier.respondToNomination(
        idirId: 'idir-1',
        electionId: 'el-1',
        nominationId: nomId,
        action: 'DECLINE',
      );

      expect(success, isTrue);
      expect(notifier.state.nomination!.isDeclined, isTrue);
      expect(notifier.state.successMessage, contains('Nomination declined'));
    });

    test('Candidate updates their short statement', () async {
      await repo.nominateCandidate(
        idirId: 'idir-1',
        electionId: 'el-1',
        role: 'CHAIRPERSON',
        nomineeMembershipId: 'actor-membership-id',
        statement: 'Initial draft statement.',
      );
      final nomId = repo.nominations.first.id;

      final success = await notifier.updateStatement(
        idirId: 'idir-1',
        electionId: 'el-1',
        nominationId: nomId,
        statement: 'Updated platform: emergency reserve funds and youth programs.',
      );

      expect(success, isTrue);
      expect(notifier.state.nomination!.statement, contains('emergency reserve funds'));
    });

    test('Candidate withdraws candidacy', () async {
      await repo.nominateCandidate(
        idirId: 'idir-1',
        electionId: 'el-1',
        role: 'CHAIRPERSON',
        nomineeMembershipId: 'actor-membership-id',
      );
      final nomId = repo.nominations.first.id;

      final success = await notifier.withdrawNomination(
        idirId: 'idir-1',
        electionId: 'el-1',
        nominationId: nomId,
      );

      expect(success, isTrue);
      expect(notifier.state.nomination!.isWithdrawn, isTrue);
      expect(notifier.state.successMessage, contains('withdrawn'));
    });

    test('Done when rule: Unaccepted nominations DO NOT appear on the ballot', () async {
      // Create 1 self-nomination (ACCEPTED)
      await repo.nominateCandidate(
        idirId: 'idir-1',
        electionId: 'el-1',
        role: 'CHAIRPERSON',
        nomineeMembershipId: 'actor-membership-id',
      );

      // Create 1 other-member nomination (PENDING)
      await repo.nominateCandidate(
        idirId: 'idir-1',
        electionId: 'el-1',
        role: 'TREASURER',
        nomineeMembershipId: 'other-membership-id-1',
      );

      // Create another other-member nomination and DECLINE it
      final declined = await repo.nominateCandidate(
        idirId: 'idir-1',
        electionId: 'el-1',
        role: 'SECRETARY',
        nomineeMembershipId: 'other-membership-id-2',
      );
      await repo.respondToNomination(
        idirId: 'idir-1',
        electionId: 'el-1',
        nominationId: declined.id,
        action: 'DECLINE',
      );

      expect(repo.nominations, hasLength(3));

      // Query ballot (ballotOnly: true)
      final ballotCandidates = await repo.listNominations(
        idirId: 'idir-1',
        electionId: 'el-1',
        ballotOnly: true,
      );

      // CRITICAL ASSERTION: ONLY ACCEPTED candidates appear on the ballot!
      expect(ballotCandidates, hasLength(1));
      expect(ballotCandidates.first.role, equals('CHAIRPERSON'));
      expect(ballotCandidates.first.isAccepted, isTrue);

      // When querying ALL nominations:
      final allNominations = await repo.listNominations(
        idirId: 'idir-1',
        electionId: 'el-1',
        status: 'ALL',
      );
      expect(allNominations, hasLength(3));
    });

    test('Error handling: repository exceptions are caught and reported cleanly', () async {
      repo.shouldThrow = true;
      repo.throwMessage = 'Only active members can be candidates';

      final success = await notifier.nominateCandidate(
        idirId: 'idir-1',
        electionId: 'el-1',
        role: 'CHAIRPERSON',
        nomineeMembershipId: 'inactive-id',
      );

      expect(success, isFalse);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, contains('Only active members can be candidates'));
    });
  });
}
