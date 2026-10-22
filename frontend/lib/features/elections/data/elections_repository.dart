import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../domain/models/election_model.dart';

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
