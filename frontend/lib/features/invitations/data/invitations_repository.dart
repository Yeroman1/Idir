import 'package:supabase_flutter/supabase_flutter.dart';
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
    // 1. Check live Supabase database directly for real-time status
    try {
      final sb = Supabase.instance.client;
      if (email != null && email.trim().isNotEmpty) {
        final cleanEmail = email.trim().toLowerCase();
        final rows = await sb
            .from('User')
            .select('id, fullName, email, phoneNumber')
            .ilike('email', cleanEmail)
            .limit(1);

        if (rows.isNotEmpty) {
          final user = Map<String, dynamic>.from(rows.first);
          bool isAlreadyMember = false;
          if (!idirId.startsWith('draft-') && idirId.isNotEmpty) {
            try {
              final mRows = await sb
                  .from('Membership')
                  .select('id')
                  .eq('idirId', idirId)
                  .eq('userId', user['id'])
                  .eq('status', 'ACTIVE')
                  .limit(1);
              isAlreadyMember = mRows.isNotEmpty;
            } catch (_) {}
          }

          if (isAlreadyMember) {
            return {
              'exists': true,
              'user': user,
              'isAlreadyMember': true,
              'message': '${user['fullName']} is already an active member of this Idir.',
            };
          }

          return {
            'exists': true,
            'user': user,
            'isAlreadyMember': false,
            'message': 'User found: ${user['fullName']} (${user['email'] ?? user['phoneNumber']}).',
          };
        }
      } else if (phone != null && phone.trim().isNotEmpty) {
        final cleanPhone = phone.trim();
        final digits = cleanPhone.replaceAll(RegExp(r'\D'), '');
        final last9 = digits.length >= 9 ? digits.substring(digits.length - 9) : digits;

        final rows = await sb
            .from('User')
            .select('id, fullName, email, phoneNumber')
            .or('phoneNumber.ilike.%$last9%,phoneNumber.eq.$cleanPhone')
            .limit(1);

        if (rows.isNotEmpty) {
          final user = Map<String, dynamic>.from(rows.first);
          bool isAlreadyMember = false;
          if (!idirId.startsWith('draft-') && idirId.isNotEmpty) {
            try {
              final mRows = await sb
                  .from('Membership')
                  .select('id')
                  .eq('idirId', idirId)
                  .eq('userId', user['id'])
                  .eq('status', 'ACTIVE')
                  .limit(1);
              isAlreadyMember = mRows.isNotEmpty;
            } catch (_) {}
          }

          if (isAlreadyMember) {
            return {
              'exists': true,
              'user': user,
              'isAlreadyMember': true,
              'message': '${user['fullName']} is already an active member of this Idir.',
            };
          }

          return {
            'exists': true,
            'user': user,
            'isAlreadyMember': false,
            'message': 'User found: ${user['fullName']} (${user['phoneNumber'] ?? user['email']}).',
          };
        }
      }
    } catch (sbErr) {
      debugPrint('[InvitationsRepository] Live Supabase lookup notice: $sbErr');
    }

    // 2. Query backend REST API (with unauthenticated check-user support)
    try {
      final query = email != null && email.isNotEmpty
          ? 'email=${Uri.encodeComponent(email.trim().toLowerCase())}'
          : 'phone=${Uri.encodeComponent((phone ?? '').trim())}';
      final res = await _api.get(
        '/idirs/$idirId/invitations/check-user?$query',
        requiresAuth: false,
      );

      if (res is Map<String, dynamic>) {
        return res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : res;
      }
    } catch (apiErr) {
      debugPrint('[InvitationsRepository] Backend checkUser notice: $apiErr');
    }

    final identifier = (email != null && email.isNotEmpty) ? email.trim() : (phone ?? '').trim();
    return {
      'exists': false,
      'message': 'No user found registered with "$identifier". The user must register first.',
    };
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
