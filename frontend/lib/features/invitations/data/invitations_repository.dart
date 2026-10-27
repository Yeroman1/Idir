import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../domain/models/invitation_result.dart';
import '../domain/models/received_invitation.dart';

abstract class InvitationsRepository {
  Future<BatchInvitationResult> sendBatchInvitations({
    required String idirId,
    List<String> phoneNumbers = const [],
    List<String> emails = const [],
    int expiresInDays = 7,
  });

  Future<Map<String, dynamic>> checkUserRegistration({
    required String idirId,
    String? phone,
    String? email,
  });

  Future<PublicInvitationDetails> verifyToken(String token);

  Future<Map<String, dynamic>> respondToInvitation({
    required String token,
    required String action,
  });

  Future<List<ReceivedInvitation>> getReceivedInvitations();

  Future<Map<String, dynamic>> respondToReceivedInvitation({
    required String invitationId,
    required String action,
  });
}

class RestInvitationsRepository implements InvitationsRepository {
  RestInvitationsRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  @override
  Future<BatchInvitationResult> sendBatchInvitations({
    required String idirId,
    List<String> phoneNumbers = const [],
    List<String> emails = const [],
    int expiresInDays = 7,
  }) async {
    final payload = {
      if (phoneNumbers.isNotEmpty) 'phoneNumbers': phoneNumbers,
      if (emails.isNotEmpty) 'emails': emails,
      'expiresInDays': expiresInDays,
    };

    final res = await _api.post('/idirs/$idirId/invitations/batch', body: payload);

    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
      return BatchInvitationResult.fromMap(data);
    }

    throw Exception('Unexpected response format when sending invitations');
  }

  @override
  Future<Map<String, dynamic>> checkUserRegistration({
    required String idirId,
    String? phone,
    String? email,
  }) async {
    final query = email != null && email.isNotEmpty
        ? 'email=${Uri.encodeComponent(email.trim())}'
        : 'phone=${Uri.encodeComponent((phone ?? '').trim())}';
    final res = await _api.get('/idirs/$idirId/invitations/check-user?$query');

    if (res is Map<String, dynamic>) {
      return res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
    }

    return {'exists': false, 'message': 'Unable to check user'};
  }

  @override
  Future<PublicInvitationDetails> verifyToken(String token) async {
    final res = await _api.get('/invitations/verify?token=$token');

    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
      return PublicInvitationDetails.fromMap(data);
    }

    throw Exception('This invitation link is invalid or has expired');
  }

  @override
  Future<Map<String, dynamic>> respondToInvitation({
    required String token,
    required String action,
  }) async {
    final res = await _api.post('/invitations/respond', body: {
      'token': token,
      'action': action,
    });

    if (res is Map<String, dynamic>) {
      return res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
    }

    return {'success': true};
  }

  @override
  Future<List<ReceivedInvitation>> getReceivedInvitations() async {
    try {
      final res = await _api.get('/invitations/received');
      List<dynamic>? rawList;
      if (res is List) {
        rawList = res;
      } else if (res is Map<String, dynamic> && res['data'] is List) {
        rawList = res['data'] as List<dynamic>;
      }

      if (rawList != null) {
        return rawList
            .map((item) => ReceivedInvitation.fromMap(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[InvitationsRepository] getReceivedInvitations error: $e');
    }
    return const [];
  }

  @override
  Future<Map<String, dynamic>> respondToReceivedInvitation({
    required String invitationId,
    required String action,
  }) async {
    final res = await _api.post('/invitations/$invitationId/respond', body: {
      'action': action,
    });

    if (res is Map<String, dynamic>) {
      return res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
    }

    return {'success': true};
  }
}

final invitationsRepositoryProvider = Provider<InvitationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RestInvitationsRepository(apiClient: apiClient);
});
