import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/features/claims/data/claims_repository.dart';
import 'package:idir_app/features/claims/domain/models/claim.dart';
import 'package:idir_app/features/expenses/data/expenses_repository.dart';
import 'package:idir_app/features/expenses/domain/models/expense.dart';
import 'package:idir_app/features/members/data/members_repository.dart';

void main() {
  group('Claims & Expenses unit tests', () {
    late ExpensesRepository expensesRepo;
    late MembersRepository membersRepo;
    late ClaimsRepository claimsRepo;

    setUp(() {
      expensesRepo = FirestoreExpensesRepository();
      membersRepo = FirestoreMembersRepository();
      claimsRepo = FirestoreClaimsRepository(
        expensesRepository: expensesRepo,
        membersRepository: membersRepo,
      );
    });

    test('Loads initial sample claims and expenses', () async {
      final claims = await claimsRepo.getClaims();
      expect(claims.length, greaterThanOrEqualTo(2));

      final expenses = await expensesRepo.getExpenses();
      expect(expenses.length, greaterThanOrEqualTo(2));
    });

    test('Self-approval prevention: Officer cannot approve a claim they submitted', () async {
      final now = DateTime.now();
      final claim = Claim(
        id: 'test_claim_self',
        claimNumber: 'CLM-2024-999',
        memberId: 'MEM-001',
        memberName: 'Abebe Tadesse',
        type: ClaimType.funeral,
        description: 'Self-approval test',
        requestedAmount: 3000.0,
        status: ClaimStatus.submitted,
        submittedBy: 'officer_uid_1',
        submittedByName: 'Officer Abebe',
        approvals: const [],
        createdAt: now,
      );

      await claimsRepo.submitClaim(claim);

      // Verify domain check
      expect(claim.canVote('officer_uid_1', UserRole.chairperson), isFalse);

      // Verify repository throws self-approval exception
      expect(
        () async => claimsRepo.voteOnClaim(
          claimId: claim.id,
          uid: 'officer_uid_1',
          name: 'Officer Abebe',
          role: 'chairperson',
          decision: 'approved',
          comment: 'Approving my own claim',
        ),
        throwsA(predicate((e) => e.toString().contains('Self-approval prevention'))),
      );
    });

    test('Two approvals from distinct officers transition claim to approved', () async {
      final now = DateTime.now();
      final claim = Claim(
        id: 'test_claim_flow',
        claimNumber: 'CLM-2024-888',
        memberId: 'MEM-002',
        memberName: 'Fatuma Mohammed',
        type: ClaimType.funeral,
        description: 'Multi-officer approval test',
        requestedAmount: 3000.0,
        status: ClaimStatus.submitted,
        submittedBy: 'member_uid_9',
        submittedByName: 'Fatuma Mohammed',
        approvals: const [],
        createdAt: now,
      );

      await claimsRepo.submitClaim(claim);

      // 1. First officer votes
      final afterFirst = await claimsRepo.voteOnClaim(
        claimId: claim.id,
        uid: 'chair_uid',
        name: 'Abebe (Chair)',
        role: 'chairperson',
        decision: 'approved',
        comment: 'Verified burial documents',
        approvalsRequired: 2,
      );

      expect(afterFirst.status, ClaimStatus.submitted);
      expect(afterFirst.approvedCount, 1);

      // Duplicate vote rejection test
      expect(
        () async => claimsRepo.voteOnClaim(
          claimId: claim.id,
          uid: 'chair_uid',
          name: 'Abebe (Chair)',
          role: 'chairperson',
          decision: 'approved',
          comment: 'Voting again',
          approvalsRequired: 2,
        ),
        throwsA(predicate((e) => e.toString().contains('already cast your vote'))),
      );

      // 2. Second officer votes -> transitions to approved
      final afterSecond = await claimsRepo.voteOnClaim(
        claimId: claim.id,
        uid: 'treasurer_uid',
        name: 'Chaltu (Treasurer)',
        role: 'treasurer',
        decision: 'approved',
        comment: 'Dues up to date',
        approvalsRequired: 2,
      );

      expect(afterSecond.status, ClaimStatus.approved);
      expect(afterSecond.approvedCount, 2);
    });

    test('Disbursing payout creates an expense record and marks claim as paid', () async {
      final now = DateTime.now();
      final approvedClaim = Claim(
        id: 'test_claim_payout',
        claimNumber: 'CLM-2024-777',
        memberId: 'MEM-001',
        memberName: 'Abebe Tadesse',
        type: ClaimType.illness,
        description: 'Hospital support',
        requestedAmount: 2000.0,
        status: ClaimStatus.approved,
        submittedBy: 'member_uid_1',
        submittedByName: 'Abebe Tadesse',
        approvals: [
          ClaimApproval(
            uid: 'c1',
            name: 'Chair',
            role: 'chairperson',
            decision: 'approved',
            comment: 'OK',
            at: now,
          ),
          ClaimApproval(
            uid: 't1',
            name: 'Treasurer',
            role: 'treasurer',
            decision: 'approved',
            comment: 'OK',
            at: now,
          ),
        ],
        createdAt: now,
      );

      await claimsRepo.submitClaim(approvedClaim);

      final initialExpensesCount = (await expensesRepo.getExpenses()).length;

      // Treasurer records payout
      await claimsRepo.recordPayout(
        claimId: approvedClaim.id,
        payoutAmount: 2000.0,
        recordedByUid: 't1',
        recordedByName: 'Treasurer',
      );

      // 1. Verify claim is paid
      final updatedClaim = await claimsRepo.getClaimById(approvedClaim.id);
      expect(updatedClaim!.status, ClaimStatus.paid);
      expect(updatedClaim.payoutAmount, 2000.0);
      expect(updatedClaim.paidAt, isNotNull);
      expect(updatedClaim.payoutExpenseId, isNotNull);

      // 2. Verify expense voucher was created in expenses repository
      final newExpenses = await expensesRepo.getExpenses();
      expect(newExpenses.length, initialExpensesCount + 1);

      final payoutExpense = newExpenses.firstWhere(
        (e) => e.claimId == approvedClaim.id,
      );
      expect(payoutExpense.category, ExpenseCategory.payout);
      expect(payoutExpense.amount, 2000.0);
    });

    test('Append-only expenses and atomic reversals', () async {
      final initialExpenses = await expensesRepo.getExpenses();
      final target = initialExpenses.firstWhere((e) => !e.isReversed && !e.isReversal);

      await expensesRepo.reverseExpense(
        originalId: target.id,
        reason: 'Erroneous billing entry',
        recordedByUid: 't1',
        recordedByName: 'Treasurer',
      );

      final originalUpdated = await expensesRepo.getExpenseById(target.id);
      expect(originalUpdated!.isReversed, isTrue);

      final afterReversal = await expensesRepo.getExpenses();
      final reversalRecord = afterReversal.firstWhere(
        (e) => e.isReversal && e.reversalOfId == target.id,
      );

      expect(reversalRecord.amount, target.amount);
      expect(reversalRecord.reversalReason, 'Erroneous billing entry');
      expect(reversalRecord.voucherNumber, startsWith('REV-'));
    });

    test('Claim toMap and fromMap serialization roundtrip', () {
      final now = DateTime.now();
      final claim = Claim(
        id: 'clm_rt',
        claimNumber: 'CLM-2024-042',
        memberId: 'MEM-003',
        memberName: 'Tigist Alemu',
        type: ClaimType.other,
        description: 'Roundtrip test description',
        requestedAmount: 1200.0,
        status: ClaimStatus.submitted,
        submittedBy: 'uid_tigist',
        submittedByName: 'Tigist Alemu',
        approvals: [
          ClaimApproval(
            uid: 'uid_officer',
            name: 'Officer Name',
            role: 'chairperson',
            decision: 'approved',
            comment: 'Verification ok',
            at: now,
          ),
        ],
        createdAt: now,
      );

      final map = claim.toMap();
      final restored = Claim.fromMap('clm_rt', map);

      expect(restored.id, claim.id);
      expect(restored.claimNumber, claim.claimNumber);
      expect(restored.requestedAmount, 1200.0);
      expect(restored.type, ClaimType.other);
      expect(restored.approvals.length, 1);
      expect(restored.approvals.first.comment, 'Verification ok');
    });
  });
}
