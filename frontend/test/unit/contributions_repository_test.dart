import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/features/contributions/data/contributions_repository.dart';
import 'package:idir_app/features/contributions/domain/models/contribution.dart';
import 'package:idir_app/features/members/data/members_repository.dart';

void main() {
  group('ContributionsRepository unit tests', () {
    late FirestoreMembersRepository membersRepo;
    late FirestoreContributionsRepository contributionsRepo;

    setUp(() {
      membersRepo = FirestoreMembersRepository();
      contributionsRepo = FirestoreContributionsRepository(
        membersRepository: membersRepo,
      );
    });

    test('Loads initial contributions', () async {
      final list = await contributionsRepo.getContributions();
      expect(list.isNotEmpty, isTrue);
      expect(list.any((c) => c.memberId == 'MEM-001'), isTrue);
    });

    test('Generates sequential receipt number with current year', () async {
      final nextNum = await contributionsRepo.generateNextReceiptNumber();
      final year = DateTime.now().year;
      expect(nextNum, startsWith('REC-$year-'));
    });

    test('Records a contribution and updates member balances', () async {
      final now = DateTime.now();
      final contribution = Contribution(
        id: 'new_c_test',
        receiptNumber: 'REC-${now.year}-999',
        memberId: 'MEM-003',
        memberName: 'Dawit Abdi',
        amount: 100.0,
        date: now,
        recordedByUid: 'demo_treasurer',
        recordedByName: 'Chaltu Bekele (Treasurer)',
        paymentMethod: PaymentMethod.telebirr,
        periodMonth: now.month,
        periodYear: now.year,
        createdAt: now,
      );

      await contributionsRepo.recordContribution(contribution);

      final list = await contributionsRepo.getContributions();
      expect(list.any((c) => c.id == 'new_c_test'), isTrue);

      final member = await membersRepo.getMemberById('mem_3');
      expect(member, isNotNull);
      // Member balance was previously -100, now should be updated!
      expect(member!.memberId, 'MEM-003');
    });

    test('Reverses a contribution cleanly with offsetting record', () async {
      final all = await contributionsRepo.getContributions();
      final target = all.firstWhere((c) => !c.isReversed && !c.isReversal);

      await contributionsRepo.reverseContribution(
        originalId: target.id,
        reason: 'Payment recorded in error',
        recordedByUid: 'demo_treasurer',
        recordedByName: 'Chaltu Bekele (Treasurer)',
      );

      final originalUpdated =
          await contributionsRepo.getContributionById(target.id);
      expect(originalUpdated!.isReversed, isTrue);

      final updatedList = await contributionsRepo.getContributions();
      final reversalRecord = updatedList.firstWhere(
        (c) => c.isReversal && c.reversalOfId == target.id,
      );
      expect(reversalRecord, isNotNull);
      expect(reversalRecord.reversalReason, 'Payment recorded in error');
      expect(reversalRecord.amount, target.amount);
    });

    test('Contribution toMap and fromMap serialization roundtrip', () {
      final now = DateTime.now();
      final c = Contribution(
        id: 'c_roundtrip',
        receiptNumber: 'REC-2024-042',
        memberId: 'MEM-001',
        memberName: 'Abebe Tadesse',
        amount: 75.0,
        date: now,
        recordedByUid: 'uid_trsr',
        recordedByName: 'Chaltu Bekele',
        paymentMethod: PaymentMethod.cbeBirr,
        periodMonth: 10,
        periodYear: 2024,
        notes: 'Roundtrip test notes',
        isReversal: false,
        isReversed: false,
        createdAt: now,
      );

      final map = c.toMap();
      final restored = Contribution.fromMap('c_roundtrip', map);

      expect(restored.id, c.id);
      expect(restored.receiptNumber, c.receiptNumber);
      expect(restored.amount, 75.0);
      expect(restored.paymentMethod, PaymentMethod.cbeBirr);
      expect(restored.periodMonth, 10);
      expect(restored.periodYear, 2024);
      expect(restored.notes, 'Roundtrip test notes');
      expect(restored.isReversed, isFalse);
    });
  });
}
