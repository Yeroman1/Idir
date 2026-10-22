import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../domain/models/election_model.dart';
import '../domain/models/nomination_model.dart';

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
