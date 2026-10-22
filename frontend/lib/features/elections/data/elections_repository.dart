import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../domain/models/election_model.dart';
import '../domain/models/nomination_model.dart';
import '../domain/models/vote_receipt_model.dart';
import '../domain/models/election_results_model.dart';
import '../domain/models/leadership_events_model.dart';

abstract class ElectionsRepository {
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
  });

  Future<ElectionModel> getElection({
    required String idirId,
    required String electionId,
  });

  Future<List<ElectionModel>> listElections({
    required String idirId,
    String? status,
  });

  Future<ElectionModel> updateElection({
    required String idirId,
    required String electionId,
    Map<String, dynamic> updates,
  });

  Future<void> cancelElection({
    required String idirId,
    required String electionId,
    required String reason,
  });

  Future<NominationModel> nominateCandidate({
    required String idirId,
    required String electionId,
    required String role,
    required String nomineeMembershipId,
    String? statement,
  });

  Future<NominationModel> respondToNomination({
    required String idirId,
    required String electionId,
    required String nominationId,
    required String action,
    String? statement,
  });

  Future<NominationModel> withdrawNomination({
    required String idirId,
    required String electionId,
    required String nominationId,
  });

  Future<NominationModel> updateCandidateStatement({
    required String idirId,
    required String electionId,
    required String nominationId,
    required String statement,
  });

  Future<List<NominationModel>> listNominations({
    required String idirId,
    required String electionId,
    String? role,
    String? status,
    bool? ballotOnly,
  });

  Future<NominationModel> getCandidatePage({
    required String idirId,
    required String electionId,
    required String nominationId,
  });

  Future<VoteReceiptModel> castVote({
    required String idirId,
    required String electionId,
    required String role,
    required String candidateNominationId,
  });

  Future<VotingStatusModel> getVotingStatus({
    required String idirId,
    required String electionId,
  });

  Future<Map<String, dynamic>> getBallot({
    required String idirId,
    required String electionId,
  });

  Future<ElectionResultsModel> tallyVotes({
    required String idirId,
    required String electionId,
    bool force = false,
  });

  Future<ElectionResultsModel> getResults({
    required String idirId,
    required String electionId,
  });

  Future<ElectionDisputeModel> fileDispute({
    required String idirId,
    required String electionId,
    required String reason,
  });

  Future<List<ElectionDisputeModel>> listDisputes({
    required String idirId,
    required String electionId,
  });

  Future<ElectionDisputeModel> resolveDispute({
    required String idirId,
    required String electionId,
    required String disputeId,
    required String action,
    required String resolution,
  });

  Future<Map<String, dynamic>> certifyElection({
    required String idirId,
    required String electionId,
  });

  Future<Map<String, dynamic>> triggerRunoff({
    required String idirId,
    required String electionId,
    required String role,
    DateTime? runoffEndDate,
  });

  Future<NoConfidenceVoteModel> initiateNoConfidence({
    required String idirId,
    required String targetMembershipId,
    required String targetRole,
    required String reason,
    double thresholdPercentage = 66.67,
    double quorumPercentage = 50.0,
    int durationDays = 7,
  });

  Future<List<NoConfidenceVoteModel>> listNoConfidenceVotes({
    required String idirId,
  });

  Future<NoConfidenceVoteModel> getNoConfidenceVote({
    required String idirId,
    required String voteId,
  });

  Future<Map<String, dynamic>> castNoConfidenceVote({
    required String idirId,
    required String voteId,
    required String choice,
  });

  Future<Map<String, dynamic>> resolveNoConfidenceVote({
    required String idirId,
    required String voteId,
    bool force = false,
  });

  Future<List<LeadershipVacancyModel>> getLeadershipVacancies({
    required String idirId,
  });

  Future<Map<String, dynamic>> appointTemporaryOfficer({
    required String idirId,
    required String vacantRole,
    required String appointeeMembershipId,
    String? reason,
    int termMonths = 6,
  });

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
  });
}

class RestElectionsRepository implements ElectionsRepository {
  RestElectionsRepository({
    required ApiClient apiClient,
  }) : _api = apiClient;

  final ApiClient _api;
  static const _cacheKeyPrefix = 'cached_elections_';

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
    final payload = {
      'title': title,
      if (description != null) 'description': description,
      'roles': roles,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      if (nominationStartDate != null)
        'nominationStartDate': nominationStartDate.toIso8601String(),
      if (nominationEndDate != null)
        'nominationEndDate': nominationEndDate.toIso8601String(),
      'termLengthMonths': termLengthMonths,
      'votingMethod': votingMethod,
      'ballotType': ballotType,
      'quorumPercentage': quorumPercentage,
      'minMembershipTenureDays': minMembershipTenureDays,
      'requiresGoodStanding': requiresGoodStanding,
      'disputeWindowHours': disputeWindowHours,
      if (handoverDate != null)
        'handoverDate': handoverDate.toIso8601String(),
      'committeeMemberIds': committeeMemberIds,
    };

    try {
      final res = await _api.post('/idirs/$idirId/elections', body: payload);
      Map<String, dynamic> data;
      if (res is Map<String, dynamic>) {
        data = res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : res;
      } else {
        data = Map<String, dynamic>.from(payload)
          ..['id'] = 'el-${DateTime.now().millisecondsSinceEpoch}'
          ..['idirId'] = idirId
          ..['status'] = 'DRAFT';
      }

      final created = ElectionModel.fromMap(data);
      await _cacheElectionLocally(idirId, created);
      return created;
    } catch (e) {
      // Offline fallback: cache locally if network error
      final fallback = ElectionModel(
        id: 'local-el-${DateTime.now().millisecondsSinceEpoch}',
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
        createdAt: DateTime.now(),
      );
      await _cacheElectionLocally(idirId, fallback);
      return fallback;
    }
  }

  @override
  Future<ElectionModel> getElection({
    required String idirId,
    required String electionId,
  }) async {
    try {
      final res = await _api.get('/idirs/$idirId/elections/$electionId');
      final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : (res as Map<String, dynamic>);
      return ElectionModel.fromMap(data);
    } catch (e) {
      final cached = await _getCachedElections(idirId);
      final found = cached.firstWhere(
        (el) => el.id == electionId,
        orElse: () => throw Exception('Election not found locally: $e'),
      );
      return found;
    }
  }

  @override
  Future<List<ElectionModel>> listElections({
    required String idirId,
    String? status,
  }) async {
    try {
      final queryParams = status != null ? {'status': status} : null;
      final res = await _api.get(
        '/idirs/$idirId/elections',
        queryParams: queryParams,
      );

      final List rawList;
      if (res is Map<String, dynamic> && res['data'] is List) {
        rawList = res['data'] as List;
      } else if (res is List) {
        rawList = res;
      } else {
        rawList = [];
      }

      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map((m) => ElectionModel.fromMap(m))
          .toList();

      await _overwriteCachedElections(idirId, items);
      return items;
    } catch (_) {
      return _getCachedElections(idirId);
    }
  }

  @override
  Future<ElectionModel> updateElection({
    required String idirId,
    required String electionId,
    Map<String, dynamic> updates = const {},
  }) async {
    final res = await _api.patch(
      '/idirs/$idirId/elections/$electionId',
      body: updates,
    );

    final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);

    final updated = ElectionModel.fromMap(data);
    await _cacheElectionLocally(idirId, updated);
    return updated;
  }

  @override
  Future<void> cancelElection({
    required String idirId,
    required String electionId,
    required String reason,
  }) async {
    await _api.post(
      '/idirs/$idirId/elections/$electionId/cancel',
      body: {'reason': reason},
    );
  }

  @override
  Future<NominationModel> nominateCandidate({
    required String idirId,
    required String electionId,
    required String role,
    required String nomineeMembershipId,
    String? statement,
  }) async {
    final payload = {
      'role': role,
      'nomineeMembershipId': nomineeMembershipId,
      if (statement != null && statement.isNotEmpty) 'statement': statement,
    };

    final res = await _api.post(
      '/idirs/$idirId/elections/$electionId/nominations',
      body: payload,
    );

    final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);

    final nomination = NominationModel.fromMap(data);
    await _cacheNominationLocally(electionId, nomination);
    return nomination;
  }

  @override
  Future<NominationModel> respondToNomination({
    required String idirId,
    required String electionId,
    required String nominationId,
    required String action,
    String? statement,
  }) async {
    final payload = {
      'action': action,
      if (statement != null && statement.isNotEmpty) 'statement': statement,
    };

    final res = await _api.post(
      '/idirs/$idirId/elections/$electionId/nominations/$nominationId/respond',
      body: payload,
    );

    final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);

    final nomination = NominationModel.fromMap(data);
    await _cacheNominationLocally(electionId, nomination);
    return nomination;
  }

  @override
  Future<NominationModel> withdrawNomination({
    required String idirId,
    required String electionId,
    required String nominationId,
  }) async {
    final res = await _api.post(
      '/idirs/$idirId/elections/$electionId/nominations/$nominationId/withdraw',
    );

    final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);

    final nomination = NominationModel.fromMap(data);
    await _cacheNominationLocally(electionId, nomination);
    return nomination;
  }

  @override
  Future<NominationModel> updateCandidateStatement({
    required String idirId,
    required String electionId,
    required String nominationId,
    required String statement,
  }) async {
    final res = await _api.patch(
      '/idirs/$idirId/elections/$electionId/nominations/$nominationId/statement',
      body: {'statement': statement},
    );

    final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);

    final nomination = NominationModel.fromMap(data);
    await _cacheNominationLocally(electionId, nomination);
    return nomination;
  }

  @override
  Future<List<NominationModel>> listNominations({
    required String idirId,
    required String electionId,
    String? role,
    String? status,
    bool? ballotOnly,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (role != null) queryParams['role'] = role;
      if (status != null) queryParams['status'] = status;
      if (ballotOnly != null) queryParams['ballotOnly'] = ballotOnly.toString();

      final res = await _api.get(
        '/idirs/$idirId/elections/$electionId/nominations',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      final List rawList;
      if (res is Map<String, dynamic> && res['data'] is List) {
        rawList = res['data'] as List;
      } else if (res is List) {
        rawList = res;
      } else {
        rawList = [];
      }

      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map((m) => NominationModel.fromMap(m))
          .toList();

      await _overwriteCachedNominations(electionId, items);
      return items;
    } catch (_) {
      final cached = await _getCachedNominations(electionId);
      if (ballotOnly == true || (ballotOnly == null && status == null)) {
        return cached.where((n) => n.isAccepted).toList();
      }
      if (status != null && status != 'ALL') {
        return cached.where((n) => n.status.toUpperCase() == status.toUpperCase()).toList();
      }
      return cached;
    }
  }

  @override
  Future<NominationModel> getCandidatePage({
    required String idirId,
    required String electionId,
    required String nominationId,
  }) async {
    try {
      final res = await _api.get(
        '/idirs/$idirId/elections/$electionId/nominations/$nominationId',
      );

      final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : (res as Map<String, dynamic>);

      return NominationModel.fromMap(data);
    } catch (e) {
      final cached = await _getCachedNominations(electionId);
      final found = cached.firstWhere(
        (n) => n.id == nominationId,
        orElse: () => throw Exception('Candidate page not found locally: $e'),
      );
      return found;
    }
  }

  @override
  Future<VoteReceiptModel> castVote({
    required String idirId,
    required String electionId,
    required String role,
    required String candidateNominationId,
  }) async {
    final payload = {
      'role': role,
      'candidateNominationId': candidateNominationId,
    };

    final res = await _api.post(
      '/idirs/$idirId/elections/$electionId/vote',
      body: payload,
    );

    final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);

    final receipt = VoteReceiptModel.fromMap(data);
    await _cacheVoteReceiptLocally(electionId, receipt);
    return receipt;
  }

  @override
  Future<VotingStatusModel> getVotingStatus({
    required String idirId,
    required String electionId,
  }) async {
    try {
      final res = await _api.get(
        '/idirs/$idirId/elections/$electionId/voting-status',
      );

      final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : (res as Map<String, dynamic>);

      return VotingStatusModel.fromMap(data);
    } catch (_) {
      final cachedReceipts = await _getCachedVoteReceipts(electionId);
      final votedRoles = cachedReceipts.map((r) => r.role).toList();
      return VotingStatusModel(
        electionId: electionId,
        electionTitle: 'Leadership Election',
        ballotType: 'SECRET',
        votingMethod: 'SIMPLE_MAJORITY',
        isWindowOpen: true,
        isFaydaVerified: true,
        isTenureEligible: true,
        canVote: true,
        roles: votedRoles,
        votedRoles: votedRoles,
        pendingRoles: const [],
        receipts: cachedReceipts,
        allRolesVoted: false,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getBallot({
    required String idirId,
    required String electionId,
  }) async {
    final res = await _api.get(
      '/idirs/$idirId/elections/$electionId/ballot',
    );

    return res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);
  }

  // ── Results, Disputes & Certification (Task 4) ─────────────────────────────
  @override
  Future<ElectionResultsModel> tallyVotes({
    required String idirId,
    required String electionId,
    bool force = false,
  }) async {
    final res = await _api.post(
      '/idirs/$idirId/elections/$electionId/tally',
      body: {'force': force},
    );

    final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);

    return ElectionResultsModel.fromMap(data);
  }

  @override
  Future<ElectionResultsModel> getResults({
    required String idirId,
    required String electionId,
  }) async {
    final res = await _api.get(
      '/idirs/$idirId/elections/$electionId/results',
    );

    final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);

    return ElectionResultsModel.fromMap(data);
  }

  @override
  Future<ElectionDisputeModel> fileDispute({
    required String idirId,
    required String electionId,
    required String reason,
  }) async {
    final res = await _api.post(
      '/idirs/$idirId/elections/$electionId/disputes',
      body: {'reason': reason},
    );

    final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);

    return ElectionDisputeModel.fromMap(data);
  }

  @override
  Future<List<ElectionDisputeModel>> listDisputes({
    required String idirId,
    required String electionId,
  }) async {
    final res = await _api.get(
      '/idirs/$idirId/elections/$electionId/disputes',
    );

    final raw = res is Map<String, dynamic> && res['data'] is List
        ? res['data'] as List
        : (res is List ? res : []);

    return raw
        .whereType<Map<String, dynamic>>()
        .map((m) => ElectionDisputeModel.fromMap(m))
        .toList();
  }

  @override
  Future<ElectionDisputeModel> resolveDispute({
    required String idirId,
    required String electionId,
    required String disputeId,
    required String action,
    required String resolution,
  }) async {
    final res = await _api.post(
      '/idirs/$idirId/elections/$electionId/disputes/$disputeId/resolve',
      body: {
        'action': action,
        'resolution': resolution,
      },
    );

    final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);

    return ElectionDisputeModel.fromMap(data);
  }

  @override
  Future<Map<String, dynamic>> certifyElection({
    required String idirId,
    required String electionId,
  }) async {
    final res = await _api.post(
      '/idirs/$idirId/elections/$electionId/certify',
    );

    return res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> triggerRunoff({
    required String idirId,
    required String electionId,
    required String role,
    DateTime? runoffEndDate,
  }) async {
    final res = await _api.post(
      '/idirs/$idirId/elections/$electionId/runoff',
      body: {
        'role': role,
        if (runoffEndDate != null) 'runoffEndDate': runoffEndDate.toIso8601String(),
      },
    );

    return res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);
  }

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
    final res = await _api.post(
      '/idirs/$idirId/elections/no-confidence',
      body: {
        'targetMembershipId': targetMembershipId,
        'targetRole': targetRole,
        'reason': reason,
        'thresholdPercentage': thresholdPercentage,
        'quorumPercentage': quorumPercentage,
        'durationDays': durationDays,
      },
    );

    final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);

    return NoConfidenceVoteModel.fromMap(data);
  }

  @override
  Future<List<NoConfidenceVoteModel>> listNoConfidenceVotes({
    required String idirId,
  }) async {
    final res = await _api.get(
      '/idirs/$idirId/elections/no-confidence',
    );

    final raw = res is Map<String, dynamic> && res['data'] is List
        ? res['data'] as List
        : (res is List ? res : []);

    return raw
        .whereType<Map<String, dynamic>>()
        .map((m) => NoConfidenceVoteModel.fromMap(m))
        .toList();
  }

  @override
  Future<NoConfidenceVoteModel> getNoConfidenceVote({
    required String idirId,
    required String voteId,
  }) async {
    final res = await _api.get(
      '/idirs/$idirId/elections/no-confidence/$voteId',
    );

    final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);

    return NoConfidenceVoteModel.fromMap(data);
  }

  @override
  Future<Map<String, dynamic>> castNoConfidenceVote({
    required String idirId,
    required String voteId,
    required String choice,
  }) async {
    final res = await _api.post(
      '/idirs/$idirId/elections/no-confidence/$voteId/vote',
      body: {
        'choice': choice,
      },
    );

    return res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> resolveNoConfidenceVote({
    required String idirId,
    required String voteId,
    bool force = false,
  }) async {
    final res = await _api.post(
      '/idirs/$idirId/elections/no-confidence/$voteId/resolve',
      body: {
        'force': force,
      },
    );

    return res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);
  }

  @override
  Future<List<LeadershipVacancyModel>> getLeadershipVacancies({
    required String idirId,
  }) async {
    final res = await _api.get(
      '/idirs/$idirId/elections/vacancies/status',
    );

    final raw = res is Map<String, dynamic> && res['data'] is List
        ? res['data'] as List
        : (res is List ? res : []);

    return raw
        .whereType<Map<String, dynamic>>()
        .map((m) => LeadershipVacancyModel.fromMap(m))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> appointTemporaryOfficer({
    required String idirId,
    required String vacantRole,
    required String appointeeMembershipId,
    String? reason,
    int termMonths = 6,
  }) async {
    final res = await _api.post(
      '/idirs/$idirId/elections/vacancies/appoint',
      body: {
        'vacantRole': vacantRole,
        'appointeeMembershipId': appointeeMembershipId,
        if (reason != null) 'reason': reason,
        'termMonths': termMonths,
      },
    );

    return res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);
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
    final res = await _api.post(
      '/idirs/$idirId/elections/vacancies/by-election',
      body: {
        'vacantRole': vacantRole,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        if (nominationStartDate != null)
          'nominationStartDate': nominationStartDate.toIso8601String(),
        if (nominationEndDate != null)
          'nominationEndDate': nominationEndDate.toIso8601String(),
        'committeeMemberIds': committeeMemberIds,
        'quorumPercentage': quorumPercentage,
        'termLengthMonths': termLengthMonths,
      },
    );

    final data = res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);

    return ElectionModel.fromMap(data);
  }

  static const _receiptCacheKeyPrefix = 'cached_vote_receipts_';

  Future<void> _cacheVoteReceiptLocally(String electionId, VoteReceiptModel item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await _getCachedVoteReceipts(electionId);
      final idx = list.indexWhere((r) => r.role == item.role);
      if (idx >= 0) {
        list[idx] = item;
      } else {
        list.add(item);
      }
      final encoded = jsonEncode(list.map((r) => r.toMap()).toList());
      await prefs.setString('$_receiptCacheKeyPrefix$electionId', encoded);
    } catch (_) {}
  }

  Future<List<VoteReceiptModel>> _getCachedVoteReceipts(String electionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_receiptCacheKeyPrefix$electionId');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => VoteReceiptModel.fromMap(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static const _nomCacheKeyPrefix = 'cached_nominations_';

  Future<void> _cacheNominationLocally(String electionId, NominationModel item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await _getCachedNominations(electionId);
      final idx = list.indexWhere((n) => n.id == item.id);
      if (idx >= 0) {
        list[idx] = item;
      } else {
        list.insert(0, item);
      }
      final encoded = jsonEncode(list.map((n) => n.toMap()).toList());
      await prefs.setString('$_nomCacheKeyPrefix$electionId', encoded);
    } catch (_) {}
  }

  Future<void> _overwriteCachedNominations(String electionId, List<NominationModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(items.map((n) => n.toMap()).toList());
      await prefs.setString('$_nomCacheKeyPrefix$electionId', encoded);
    } catch (_) {}
  }

  Future<List<NominationModel>> _getCachedNominations(String electionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_nomCacheKeyPrefix$electionId');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => NominationModel.fromMap(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Local caching helpers ──────────────────────────────────────────────────
  Future<void> _cacheElectionLocally(String idirId, ElectionModel election) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await _getCachedElections(idirId);
      final idx = list.indexWhere((e) => e.id == election.id);
      if (idx >= 0) {
        list[idx] = election;
      } else {
        list.insert(0, election);
      }
      final encoded = jsonEncode(list.map((e) => e.toMap()).toList());
      await prefs.setString('$_cacheKeyPrefix$idirId', encoded);
    } catch (_) {}
  }

  Future<void> _overwriteCachedElections(
      String idirId, List<ElectionModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(items.map((e) => e.toMap()).toList());
      await prefs.setString('$_cacheKeyPrefix$idirId', encoded);
    } catch (_) {}
  }

  Future<List<ElectionModel>> _getCachedElections(String idirId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cacheKeyPrefix$idirId');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => ElectionModel.fromMap(m))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

final electionsRepositoryProvider = Provider<ElectionsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RestElectionsRepository(apiClient: apiClient);
});
