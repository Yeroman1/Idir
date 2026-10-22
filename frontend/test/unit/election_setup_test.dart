import 'package:flutter_test/flutter_test.dart';

import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/features/elections/domain/models/election_model.dart';
import 'package:idir_app/features/elections/domain/models/nomination_model.dart';
import 'package:idir_app/features/elections/domain/models/vote_receipt_model.dart';
import 'package:idir_app/features/elections/data/elections_repository.dart';
import 'package:idir_app/features/elections/presentation/providers/elections_provider.dart';

class MockElectionsRepository implements ElectionsRepository {
  ElectionModel? lastCreated;
  List<ElectionModel> mockList = [];

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
  }) async {
    final created = ElectionModel(
      id: 'mock-election-uuid-1',
      idirId: idirId,
      title: title,
      description: description,
      roles: roles,
      startDate: startDate,
      endDate: endDate,
      nominationStartDate: nominationStartDate,
      nominationEndDate: nominationEndDate,
      termLengthMonths: termLengthMonths,
      votingMethod: votingMethod,
      ballotType: ballotType,
      quorumPercentage: quorumPercentage,
      minMembershipTenureDays: minMembershipTenureDays,
      requiresGoodStanding: requiresGoodStanding,
      status: 'DRAFT',
      disputeWindowHours: disputeWindowHours,
      handoverDate: handoverDate,
      committeeMembers: committeeMemberIds
          .map((id) => ElectionCommitteeMemberModel(
                id: 'cm-$id',
                membershipId: id,
                role: 'COMMITTEE_MEMBER',
              ))
          .toList(),
      createdAt: DateTime.now(),
    );
    lastCreated = created;
    mockList.add(created);
    return created;
  }

  @override
  Future<ElectionModel> getElection({
    required String idirId,
    required String electionId,
  }) async {
    return mockList.firstWhere((e) => e.id == electionId);
  }

  @override
  Future<List<ElectionModel>> listElections({
    required String idirId,
    String? status,
  }) async {
    if (status != null) {
      return mockList.where((e) => e.status == status).toList();
    }
    return mockList;
  }

  @override
  Future<ElectionModel> updateElection({
    required String idirId,
    required String electionId,
    Map<String, dynamic> updates = const {},
  }) async {
    return mockList.firstWhere((e) => e.id == electionId);
  }

  @override
  Future<void> cancelElection({
    required String idirId,
    required String electionId,
    required String reason,
  }) async {}

  @override
  Future<NominationModel> nominateCandidate({
    required String idirId,
    required String electionId,
    required String role,
    required String nomineeMembershipId,
    String? statement,
  }) async {
    return NominationModel(
      id: 'nom-1',
      electionId: electionId,
      role: role,
      nomineeMembershipId: nomineeMembershipId,
      nominatedByMembershipId: nomineeMembershipId,
      statement: statement,
      status: 'ACCEPTED',
    );
  }

  @override
  Future<NominationModel> respondToNomination({
    required String idirId,
    required String electionId,
    required String nominationId,
    required String action,
    String? statement,
  }) async {
    return NominationModel(
      id: nominationId,
      electionId: electionId,
      role: 'CHAIRPERSON',
      nomineeMembershipId: 'm-1',
      nominatedByMembershipId: 'm-2',
      statement: statement,
      status: action == 'ACCEPT' ? 'ACCEPTED' : 'DECLINED',
    );
  }

  @override
  Future<NominationModel> withdrawNomination({
    required String idirId,
    required String electionId,
    required String nominationId,
  }) async {
    return NominationModel(
      id: nominationId,
      electionId: electionId,
      role: 'CHAIRPERSON',
      nomineeMembershipId: 'm-1',
      nominatedByMembershipId: 'm-2',
      status: 'WITHDRAWN',
    );
  }

  @override
  Future<NominationModel> updateCandidateStatement({
    required String idirId,
    required String electionId,
    required String nominationId,
    required String statement,
  }) async {
    return NominationModel(
      id: nominationId,
      electionId: electionId,
      role: 'CHAIRPERSON',
      nomineeMembershipId: 'm-1',
      nominatedByMembershipId: 'm-2',
      statement: statement,
      status: 'ACCEPTED',
    );
  }

  @override
  Future<List<NominationModel>> listNominations({
    required String idirId,
    required String electionId,
    String? role,
    String? status,
    bool? ballotOnly,
  }) async {
    return [];
  }

  @override
  Future<NominationModel> getCandidatePage({
    required String idirId,
    required String electionId,
    required String nominationId,
  }) async {
    return NominationModel(
      id: nominationId,
      electionId: electionId,
      role: 'CHAIRPERSON',
      nomineeMembershipId: 'm-1',
      nominatedByMembershipId: 'm-2',
      status: 'ACCEPTED',
    );
  }

  @override
  Future<VoteReceiptModel> castVote({
    required String idirId,
    required String electionId,
    required String role,
    required String candidateNominationId,
  }) async {
    return VoteReceiptModel(
      id: 'mock-receipt-1',
      electionId: electionId,
      role: role,
      votedAt: DateTime.now(),
      receiptTokenHash: 'mock-hash-1234',
    );
  }

  @override
  Future<VotingStatusModel> getVotingStatus({
    required String idirId,
    required String electionId,
  }) async {
    return const VotingStatusModel(
      electionId: 'mock-election-uuid-1',
      electionTitle: 'Mock Election',
      ballotType: 'SECRET',
      votingMethod: 'SIMPLE_MAJORITY',
      isWindowOpen: true,
      isFaydaVerified: true,
      isTenureEligible: true,
      canVote: true,
      roles: ['CHAIRPERSON'],
      votedRoles: [],
      pendingRoles: ['CHAIRPERSON'],
      receipts: [],
      allRolesVoted: false,
    );
  }

  @override
  Future<Map<String, dynamic>> getBallot({
    required String idirId,
    required String electionId,
  }) async {
    return {'electionId': electionId, 'roles': []};
  }
}

void main() {
  group('Task 1: Leadership Election Setup - Frontend Unit Tests', () {
    test('UserRole permissions: only Chairperson can manage/create elections', () {
      expect(UserRole.chairperson.canManageElections, isTrue);
      expect(UserRole.treasurer.canManageElections, isFalse);
      expect(UserRole.auditor.canManageElections, isFalse);
      expect(UserRole.member.canManageElections, isFalse);
    });

    test('ElectionModel serialization, deserialization and status helpers', () {
      final now = DateTime.now();
      final end = now.add(const Duration(days: 4));

      final model = ElectionModel(
        id: 'el-100',
        idirId: 'idir-200',
        title: '2026 Executive Committee Election',
        description: 'Bylaw approved leadership vote',
        roles: const ['CHAIRPERSON', 'TREASURER', 'SECRETARY'],
        startDate: now,
        endDate: end,
        termLengthMonths: 24,
        votingMethod: 'SIMPLE_MAJORITY',
        ballotType: 'SECRET',
        quorumPercentage: 50.0,
        minMembershipTenureDays: 90,
        requiresGoodStanding: true,
        status: 'DRAFT',
        disputeWindowHours: 48,
        committeeMembers: const [
          ElectionCommitteeMemberModel(
            id: 'cm-1',
            membershipId: 'mem-101',
            memberNumber: 'MEM-001',
            fullName: 'Abebe Kebede',
          ),
        ],
      );

      expect(model.isDraft, isTrue);
      expect(model.isVoting, isFalse);
      expect(model.isSecretBallot, isTrue);
      expect(model.isRunoff, isFalse);

      final map = model.toMap();
      expect(map['title'], '2026 Executive Committee Election');
      expect(map['quorumPercentage'], 50.0);
      expect(map['roles'], contains('CHAIRPERSON'));

      final fromMap = ElectionModel.fromMap(map);
      expect(fromMap.id, model.id);
      expect(fromMap.title, model.title);
      expect(fromMap.roles, model.roles);
      expect(fromMap.committeeMembers.length, 1);
      expect(fromMap.committeeMembers.first.fullName, 'Abebe Kebede');
    });

    group('ElectionCreationNotifier: Client-Side Validation Rules', () {
      late MockElectionsRepository mockRepo;
      late ElectionCreationNotifier notifier;

      setUp(() {
        mockRepo = MockElectionsRepository();
        notifier = ElectionCreationNotifier(mockRepo);
      });

      test('rejects election title shorter than 3 characters', () {
        final err = notifier.validateSettings(
          title: 'El',
          roles: ['CHAIRPERSON'],
          startDate: DateTime.now().add(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 3)),
          termLengthMonths: 12,
          quorumPercentage: 50.0,
          committeeMemberIds: ['neutral-1'],
        );
        expect(err, contains('at least 3 characters'));
      });

      test('rejects empty contested roles list', () {
        final err = notifier.validateSettings(
          title: 'General Leadership Election',
          roles: [],
          startDate: DateTime.now().add(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 3)),
          termLengthMonths: 12,
          quorumPercentage: 50.0,
          committeeMemberIds: ['neutral-1'],
        );
        expect(err, contains('select at least one leadership role'));
      });

      test('rejects voting endDate before or on startDate', () {
        final start = DateTime.now().add(const Duration(days: 3));
        final end = DateTime.now().add(const Duration(days: 1));

        final err = notifier.validateSettings(
          title: 'General Leadership Election',
          roles: ['CHAIRPERSON'],
          startDate: start,
          endDate: end,
          termLengthMonths: 12,
          quorumPercentage: 50.0,
          committeeMemberIds: ['neutral-1'],
        );
        expect(err, contains('must be strictly after start date'));
      });

      test('rejects nominationEndDate that extends past voting startDate', () {
        final start = DateTime.now().add(const Duration(days: 3));
        final end = DateTime.now().add(const Duration(days: 5));
        final nomStart = DateTime.now().add(const Duration(days: 1));
        final nomEnd = DateTime.now().add(const Duration(days: 4)); // after voting start!

        final err = notifier.validateSettings(
          title: 'General Leadership Election',
          roles: ['CHAIRPERSON'],
          startDate: start,
          endDate: end,
          nominationStartDate: nomStart,
          nominationEndDate: nomEnd,
          termLengthMonths: 12,
          quorumPercentage: 50.0,
          committeeMemberIds: ['neutral-1'],
        );
        expect(err, contains('Nomination period must conclude on or before'));
      });

      test('rejects termLengthMonths outside valid bounds (1 to 120)', () {
        final err = notifier.validateSettings(
          title: 'General Leadership Election',
          roles: ['CHAIRPERSON'],
          startDate: DateTime.now().add(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 3)),
          termLengthMonths: 0,
          quorumPercentage: 50.0,
          committeeMemberIds: ['neutral-1'],
        );
        expect(err, contains('between 1 and 120 months'));
      });

      test('rejects quorumPercentage outside 1% to 100%', () {
        final err = notifier.validateSettings(
          title: 'General Leadership Election',
          roles: ['CHAIRPERSON'],
          startDate: DateTime.now().add(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 3)),
          termLengthMonths: 12,
          quorumPercentage: 110.0,
          committeeMemberIds: ['neutral-1'],
        );
        expect(err, contains('between 1% and 100%'));
      });

      test('rejects empty neutral committee members list', () {
        final err = notifier.validateSettings(
          title: 'General Leadership Election',
          roles: ['CHAIRPERSON'],
          startDate: DateTime.now().add(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 3)),
          termLengthMonths: 12,
          quorumPercentage: 50.0,
          committeeMemberIds: [],
        );
        expect(err, contains('At least one neutral election committee member'));
      });

      test('succeeds with valid settings and updates state', () async {
        final start = DateTime.now().add(const Duration(days: 2));
        final end = DateTime.now().add(const Duration(days: 5));

        final success = await notifier.createElection(
          idirId: 'idir-valid-1',
          title: 'Valid Leadership Election',
          description: 'Official vote',
          roles: ['CHAIRPERSON', 'TREASURER'],
          startDate: start,
          endDate: end,
          termLengthMonths: 24,
          votingMethod: 'SIMPLE_MAJORITY',
          ballotType: 'SECRET',
          quorumPercentage: 50.0,
          committeeMemberIds: ['neutral-mem-1', 'neutral-mem-2'],
        );

        expect(success, isTrue);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.errorMessage, isNull);
        expect(notifier.state.createdElection, isNotNull);
        expect(notifier.state.createdElection!.title, 'Valid Leadership Election');
        expect(notifier.state.createdElection!.roles, contains('CHAIRPERSON'));
        expect(notifier.state.createdElection!.committeeMembers.length, 2);
      });
    });
  });
}
