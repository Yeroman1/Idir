import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:idir_app/features/invitations/data/invitations_repository.dart';
import 'package:idir_app/features/invitations/domain/models/invitation_result.dart';
import 'package:idir_app/features/invitations/presentation/providers/invitations_provider.dart';
import 'package:idir_app/features/invitations/presentation/widgets/invite_members_dialog.dart';

class MockInvitationsRepository implements InvitationsRepository {
  bool shouldThrow = false;
  String errorMessage = 'Failed to send invitations';

  @override
  Future<BatchInvitationResult> sendBatchInvitations({
    required String idirId,
    required List<String> phoneNumbers,
    int expiresInDays = 7,
  }) async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }

    final sent = <InvitationItem>[];
    final skipped = <SkippedInvitation>[];

    for (final phone in phoneNumbers) {
      if (phone.contains('invalid')) {
        skipped.add(SkippedInvitation(phoneNumber: phone, reason: 'Invalid format'));
      } else {
        sent.add(
          InvitationItem(
            id: 'mock-inv-${sent.length + 1}',
            phoneNumber: phone,
            inviteUrl: 'http://localhost:8080/invitation?token=mocktoken123',
            expiresAt: DateTime.now().add(Duration(days: expiresInDays)),
          ),
        );
      }
    }

    return BatchInvitationResult(
      totalRequested: phoneNumbers.length,
      sentCount: sent.length,
      invitations: sent,
      skipped: skipped,
    );
  }

  @override
  Future<Map<String, dynamic>> checkUserRegistration({
    required String idirId,
    required String phone,
  }) async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    if (phone.contains('notfound') || phone.contains('unregistered')) {
      return {'exists': false, 'message': 'No registered user found'};
    }
    return {
      'exists': true,
      'user': {'id': 'mock-u-1', 'fullName': 'Mock User', 'phoneNumber': phone},
      'isAlreadyMember': phone.contains('existing'),
      'message': 'User found',
    };
  }

  @override
  Future<PublicInvitationDetails> verifyToken(String token) async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }

    if (token == 'invalid' || token == 'expired') {
      throw Exception('This invitation link is invalid or has expired');
    }

    return PublicInvitationDetails(
      phoneNumber: '+251911223344',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      idirId: 'mock-idir-1',
      idirName: 'Bole Medhanealem Idir',
      community: 'Bole Subcity',
      location: 'Addis Ababa',
      purpose: 'Funeral coverage and community welfare',
      rules: 'Standard idir bylaws',
      contributionAmount: 350.0,
      contributionFrequency: 'MONTHLY',
    );
  }

  @override
  Future<Map<String, dynamic>> respondToInvitation({
    required String token,
    required String action,
  }) async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }

    if (token == 'invalid') {
      throw Exception('This invitation link is invalid or has expired');
    }

    return {
      'success': true,
      'action': action,
      'message': action == 'ACCEPT'
          ? 'You have successfully joined the Idir!'
          : 'Invitation declined.',
    };
  }
}

void main() {
  group('Batch Invitations Unit Tests', () {
    test('BatchInvitationResult correctly deserializes sent invitations and skipped items', () {
      final map = {
        'totalRequested': 3,
        'sentCount': 2,
        'invitations': [
          {
            'id': 'inv-1',
            'phoneNumber': '+251911223344',
            'inviteUrl': 'http://localhost:8080/invitation?token=tok1',
            'expiresAt': '2026-10-28T12:00:00.000Z',
          },
          {
            'id': 'inv-2',
            'phoneNumber': '+251922334455',
            'inviteUrl': 'http://localhost:8080/invitation?token=tok2',
            'expiresAt': '2026-10-28T12:00:00.000Z',
          },
        ],
        'skipped': [
          {
            'phoneNumber': '0111223344',
            'reason': 'Invalid Ethiopian mobile phone number',
          },
        ],
      };

      final result = BatchInvitationResult.fromMap(map);
      expect(result.totalRequested, 3);
      expect(result.sentCount, 2);
      expect(result.invitations, hasLength(2));
      expect(result.invitations[0].phoneNumber, '+251911223344');
      expect(result.invitations[0].inviteUrl, contains('token=tok1'));
      expect(result.skipped, hasLength(1));
      expect(result.skipped[0].phoneNumber, '0111223344');
      expect(result.skipped[0].reason, contains('Invalid Ethiopian'));
    });

    test('InvitationNotifier successfully dispatches batch invitations and updates state', () async {
      final mockRepo = MockInvitationsRepository();
      final container = ProviderContainer(
        overrides: [
          invitationsRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(invitationNotifierProvider.notifier);

      final success = await notifier.sendBatch(
        idirId: 'idir-101',
        phoneNumbers: ['0911223344', '0922334455', 'invalid-phone'],
        expiresInDays: 7,
      );

      expect(success, isTrue);
      final state = container.read(invitationNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.result, isNotNull);
      expect(state.result!.sentCount, 2);
      expect(state.result!.skipped, hasLength(1));
      expect(state.result!.skipped[0].reason, 'Invalid format');
    });

    test('InvitationNotifier handles API / rate limit errors gracefully', () async {
      final mockRepo = MockInvitationsRepository();
      mockRepo.shouldThrow = true;
      mockRepo.errorMessage = 'Invitation rate limit exceeded: Maximum 100 per hour';

      final container = ProviderContainer(
        overrides: [
          invitationsRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(invitationNotifierProvider.notifier);

      final success = await notifier.sendBatch(
        idirId: 'idir-101',
        phoneNumbers: ['0911223344'],
      );

      expect(success, isFalse);
      final state = container.read(invitationNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.result, isNull);
      expect(state.error, contains('rate limit exceeded'));
    });

    test('PublicInvitationDetails correctly deserializes public view-only payload', () {
      final map = {
        'invitation': {
          'phoneNumber': '+251911223344',
          'expiresAt': '2026-10-30T10:00:00.000Z',
        },
        'idir': {
          'id': 'idir-xyz',
          'name': 'Gulele Medhanealem Idir',
          'community': 'Gulele Subcity',
          'location': 'Addis Ababa',
          'purpose': 'Mutual assistance and welfare fund',
          'rules': 'Active member attendance required',
          'contributionAmount': 400.0,
          'contributionFrequency': 'MONTHLY',
        },
      };

      final details = PublicInvitationDetails.fromMap(map);
      expect(details.idirName, 'Gulele Medhanealem Idir');
      expect(details.community, 'Gulele Subcity');
      expect(details.location, 'Addis Ababa');
      expect(details.purpose, 'Mutual assistance and welfare fund');
      expect(details.rules, 'Active member attendance required');
      expect(details.contributionAmount, 400.0);
      expect(details.contributionFrequency, 'MONTHLY');
      expect(details.phoneNumber, '+251911223344');
    });

    test('InvitationsRepository verifyToken succeeds on valid token and throws uniform error on invalid token', () async {
      final mockRepo = MockInvitationsRepository();

      final validDetails = await mockRepo.verifyToken('valid-token-123');
      expect(validDetails.idirName, 'Bole Medhanealem Idir');
      expect(validDetails.contributionAmount, 350.0);

      expect(
        () => mockRepo.verifyToken('invalid'),
        throwsA(predicate((e) => e.toString().contains('This invitation link is invalid or has expired'))),
      );

      expect(
        () => mockRepo.verifyToken('expired'),
        throwsA(predicate((e) => e.toString().contains('This invitation link is invalid or has expired'))),
      );
    });

    test('InvitationsRepository respondToInvitation handles ACCEPT and DECLINE correctly', () async {
      final mockRepo = MockInvitationsRepository();

      final acceptRes = await mockRepo.respondToInvitation(token: 'valid-token', action: 'ACCEPT');
      expect(acceptRes['success'], isTrue);
      expect(acceptRes['action'], 'ACCEPT');

      final declineRes = await mockRepo.respondToInvitation(token: 'valid-token', action: 'DECLINE');
      expect(declineRes['success'], isTrue);
      expect(declineRes['action'], 'DECLINE');
    });

    test('EthiopianPhoneInputFormatter accepts only digits and caps at 9 characters', () {
      final formatter = EthiopianPhoneInputFormatter();

      // Normal 9 digits
      var res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '911223344', selection: TextSelection(baseOffset: 9, extentOffset: 9)),
      );
      expect(res.text, '911223344');

      // More than 9 digits (attempt 10 digits)
      res = formatter.formatEditUpdate(
        const TextEditingValue(text: '911223344'),
        const TextEditingValue(text: '9112233445', selection: TextSelection(baseOffset: 10, extentOffset: 10)),
      );
      expect(res.text, '911223344');
      expect(res.text.length, 9);

      // Non-digit characters stripped
      res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '91-12a.b3 44', selection: TextSelection(baseOffset: 12, extentOffset: 12)),
      );
      expect(res.text, '9112344');

      // Pasted with +251
      res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '+251911223344', selection: TextSelection(baseOffset: 13, extentOffset: 13)),
      );
      expect(res.text, '911223344');

      // Pasted with 251 prefix
      res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '251911223344', selection: TextSelection(baseOffset: 12, extentOffset: 12)),
      );
      expect(res.text, '911223344');

      // Pasted with domestic leading 0 (e.g. 0911223344)
      res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '0911223344', selection: TextSelection(baseOffset: 10, extentOffset: 10)),
      );
      expect(res.text, '911223344');

      // Typing leading 0 is ignored/stripped
      res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '0', selection: TextSelection(baseOffset: 1, extentOffset: 1)),
      );
      expect(res.text, '');
    });
  });
}

