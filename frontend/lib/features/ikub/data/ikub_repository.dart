import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../domain/models/ikub_models.dart';

final ikubRepositoryProvider = Provider<IkubRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return IkubRepository(apiClient);
});

class IkubRepository {
  IkubRepository(this._client);

  final ApiClient _client;

  /// Fetch the active Ikub group for the active Idir
  Future<IkubGroupModel?> getActiveGroup(String idirId) async {
    try {
      final res = await _client.get('/idirs/$idirId/ikub/active');
      if (res == null) return null;
      if (res is Map<String, dynamic>) {
        return IkubGroupModel.fromJson(res);
      }
      return null;
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// List all Ikub groups (history & active)
  Future<List<IkubGroupModel>> listGroups(
    String idirId, {
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (status != null) 'status': status,
    };
    final res = await _client.get('/idirs/$idirId/ikub/groups', queryParams: query);
    if (res is List) {
      return res.map((e) => IkubGroupModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Get details of a single group
  Future<IkubGroupModel> getGroupById(String idirId, String groupId) async {
    final res = await _client.get('/idirs/$idirId/ikub/groups/$groupId');
    return IkubGroupModel.fromJson(res as Map<String, dynamic>);
  }

  /// Get real-time financial summary
  Future<IkubSummaryModel> getGroupSummary(String idirId, String groupId) async {
    final res = await _client.get('/idirs/$idirId/ikub/groups/$groupId/summary');
    return IkubSummaryModel.fromJson(res as Map<String, dynamic>);
  }

  /// Create a new Ikub group (Chairperson only)
  Future<IkubGroupModel> createGroup(
    String idirId, {
    required String name,
    String? description,
    required double contributionAmount,
    String frequency = 'WEEKLY',
    required DateTime startDate,
    int totalRounds = 10,
    String payoutRule = 'LOTTERY',
    int winnersPerRound = 1,
    String drawMode = 'DIGITAL_LOTTERY',
  }) async {
    final body = {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      'contributionAmount': contributionAmount,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'totalRounds': totalRounds,
      'payoutRule': payoutRule,
      'winnersPerRound': winnersPerRound,
      'drawMode': drawMode,
    };
    final res = await _client.post('/idirs/$idirId/ikub/groups', body: body);
    return IkubGroupModel.fromJson(res as Map<String, dynamic>);
  }

  /// Member directly joins the Ikub (1-Click Instant Enrollment)
  Future<dynamic> requestToJoin(
    String idirId,
    String groupId,
    String membershipId, {
    String? note,
  }) async {
    final res = await _client.post(
      '/idirs/$idirId/ikub/groups/$groupId/join',
      body: {
        'membershipId': membershipId,
        if (note != null) 'note': note,
      },
    );
    return res;
  }

  /// List pending join requests (Officers)
  Future<List<IkubJoinRequestModel>> listJoinRequests(
    String idirId,
    String groupId,
  ) async {
    final res = await _client.get('/idirs/$idirId/ikub/groups/$groupId/join-requests');
    if (res is List) {
      return res.map((e) => IkubJoinRequestModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Officer responds to join request (Approve/Reject)
  Future<void> respondToJoinRequest(
    String idirId,
    String groupId,
    String requestId,
    String status, // 'APPROVED' | 'REJECTED'
  ) async {
    await _client.post(
      '/idirs/$idirId/ikub/groups/$groupId/join-requests/$requestId/respond',
      body: {'status': status},
    );
  }

  /// Officer adds a participant directly
  Future<IkubParticipantModel> addParticipant(
    String idirId,
    String groupId,
    String membershipId, {
    int? payoutOrder,
  }) async {
    final res = await _client.post(
      '/idirs/$idirId/ikub/groups/$groupId/participants',
      body: {
        'membershipId': membershipId,
        if (payoutOrder != null) 'payoutOrder': payoutOrder,
      },
    );
    return IkubParticipantModel.fromJson(res as Map<String, dynamic>);
  }

  /// Execute Lottery Draw (Digital automated random or manual pick)
  Future<Map<String, dynamic>> drawLottery(
    String idirId,
    String groupId,
    String roundId, {
    String? manualWinnerId,
    String? note,
    bool? isRedraw,
    String? redrawReason,
  }) async {
    final body = {
      if (manualWinnerId != null) 'manualWinnerId': manualWinnerId,
      if (note != null) 'note': note,
      if (isRedraw != null) 'isRedraw': isRedraw,
      if (redrawReason != null) 'redrawReason': redrawReason,
    };
    final res = await _client.post(
      '/idirs/$idirId/ikub/groups/$groupId/rounds/$roundId/draw',
      body: body,
    );
    return res as Map<String, dynamic>;
  }

  /// Record member contribution for the round
  Future<void> recordContribution(
    String idirId,
    String groupId, {
    required String roundId,
    required String participantId,
    required double amount,
    String paymentMethod = 'CASH',
    String? paymentReference,
    String? clientMutationId,
  }) async {
    await _client.post(
      '/idirs/$idirId/ikub/groups/$groupId/contributions',
      body: {
        'roundId': roundId,
        'participantId': participantId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        if (paymentReference != null) 'paymentReference': paymentReference,
        if (clientMutationId != null) 'clientMutationId': clientMutationId,
      },
    );
  }

  /// Record payout disbursement to winning participant
  Future<IkubPayoutModel> recordPayout(
    String idirId,
    String groupId, {
    required String roundId,
    required String recipientParticipantId,
    required double amount,
    String paymentMethod = 'CASH',
    String? paymentReference,
  }) async {
    final res = await _client.post(
      '/idirs/$idirId/ikub/groups/$groupId/payouts',
      body: {
        'roundId': roundId,
        'recipientParticipantId': recipientParticipantId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        if (paymentReference != null) 'paymentReference': paymentReference,
      },
    );
    return IkubPayoutModel.fromJson(res as Map<String, dynamic>);
  }
}
