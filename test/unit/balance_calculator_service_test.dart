import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/features/contributions/domain/models/contribution.dart';
import 'package:idir_app/features/contributions/domain/services/balance_calculator_service.dart';
import 'package:idir_app/features/members/domain/models/member.dart';

void main() {
  group('BalanceCalculatorService unit tests', () {
    const calculator = BalanceCalculatorService();

    test('Member exactly up-to-date with payments', () {
      final regDate = DateTime(2024, 1, 1);
      final asOf = DateTime(2024, 6, 1); // 6 months active: Jan, Feb, Mar, Apr, May, Jun

      final member = Member(
        id: 'm1',
        memberId: 'MEM-001',
        fullName: 'Test Member',
        phone: '+251911000000',
        registeredAt: regDate,
        monthlyDues: 50.0,
        createdAt: regDate,
        updatedAt: regDate,
      );

      final contributions = [
        Contribution(
          id: 'c1',
          receiptNumber: 'REC-001',
          memberId: 'MEM-001',
          memberName: 'Test Member',
          amount: 300.0, // 6 months * 50 = 300
          date: regDate,
          recordedByUid: 't1',
          recordedByName: 'Treasurer',
          paymentMethod: PaymentMethod.cash,
          periodMonth: 1,
          periodYear: 2024,
          createdAt: regDate,
        ),
      ];

      final summary = calculator.calculateSummary(
        member: member,
        memberContributions: contributions,
        asOfDate: asOf,
      );

      expect(summary.monthsActive, 6);
      expect(summary.expectedDues, 300.0);
      expect(summary.totalPaid, 300.0);
      expect(summary.balance, 0.0);
      expect(summary.arrears, 0.0);
      expect(summary.arrearsMonths, 0);
      expect(summary.isInArrears, isFalse);
    });

    test('Member with prepaid surplus balance', () {
      final regDate = DateTime(2024, 1, 1);
      final asOf = DateTime(2024, 4, 1); // 4 months active = 200 ETB expected

      final member = Member(
        id: 'm1',
        memberId: 'MEM-001',
        fullName: 'Surplus Member',
        phone: '+251911000000',
        registeredAt: regDate,
        monthlyDues: 50.0,
        createdAt: regDate,
        updatedAt: regDate,
      );

      final contributions = [
        Contribution(
          id: 'c1',
          receiptNumber: 'REC-001',
          memberId: 'MEM-001',
          memberName: 'Surplus Member',
          amount: 350.0, // Paid 350 instead of 200
          date: regDate,
          recordedByUid: 't1',
          recordedByName: 'Treasurer',
          paymentMethod: PaymentMethod.telebirr,
          periodMonth: 1,
          periodYear: 2024,
          createdAt: regDate,
        ),
      ];

      final summary = calculator.calculateSummary(
        member: member,
        memberContributions: contributions,
        asOfDate: asOf,
      );

      expect(summary.monthsActive, 4);
      expect(summary.expectedDues, 200.0);
      expect(summary.totalPaid, 350.0);
      expect(summary.balance, 150.0);
      expect(summary.arrears, 0.0);
      expect(summary.arrearsMonths, 0);
      expect(summary.hasPrepaidSurplus, isTrue);
    });

    test('Member in arrears with overdue months', () {
      final regDate = DateTime(2024, 1, 1);
      final asOf = DateTime(2024, 6, 1); // 6 months active = 300 ETB expected

      final member = Member(
        id: 'm1',
        memberId: 'MEM-001',
        fullName: 'Arrears Member',
        phone: '+251911000000',
        registeredAt: regDate,
        monthlyDues: 50.0,
        createdAt: regDate,
        updatedAt: regDate,
      );

      final contributions = [
        Contribution(
          id: 'c1',
          receiptNumber: 'REC-001',
          memberId: 'MEM-001',
          memberName: 'Arrears Member',
          amount: 150.0, // Paid only 150 -> owes 150 (3 months)
          date: regDate,
          recordedByUid: 't1',
          recordedByName: 'Treasurer',
          paymentMethod: PaymentMethod.cash,
          periodMonth: 1,
          periodYear: 2024,
          createdAt: regDate,
        ),
      ];

      final summary = calculator.calculateSummary(
        member: member,
        memberContributions: contributions,
        asOfDate: asOf,
      );

      expect(summary.monthsActive, 6);
      expect(summary.expectedDues, 300.0);
      expect(summary.totalPaid, 150.0);
      expect(summary.balance, -150.0);
      expect(summary.arrears, 150.0);
      expect(summary.arrearsMonths, 3);
      expect(summary.isInArrears, isTrue);
    });

    test('Reversals properly adjust net paid amount and arrears', () {
      final regDate = DateTime(2024, 1, 1);
      final asOf = DateTime(2024, 3, 1); // 3 months active = 150 ETB expected

      final member = Member(
        id: 'm1',
        memberId: 'MEM-001',
        fullName: 'Reversal Member',
        phone: '+251911000000',
        registeredAt: regDate,
        monthlyDues: 50.0,
        createdAt: regDate,
        updatedAt: regDate,
      );

      final contributions = [
        // Original payment of 100 (which got reversed)
        Contribution(
          id: 'c1',
          receiptNumber: 'REC-001',
          memberId: 'MEM-001',
          memberName: 'Reversal Member',
          amount: 100.0,
          date: regDate,
          recordedByUid: 't1',
          recordedByName: 'Treasurer',
          paymentMethod: PaymentMethod.cash,
          periodMonth: 1,
          periodYear: 2024,
          isReversed: true, // Marked reversed
          createdAt: regDate,
        ),
        // Offsetting reversal record
        Contribution(
          id: 'c1_rev',
          receiptNumber: 'REV-001',
          memberId: 'MEM-001',
          memberName: 'Reversal Member',
          amount: 100.0,
          date: regDate,
          recordedByUid: 't1',
          recordedByName: 'Treasurer',
          paymentMethod: PaymentMethod.cash,
          periodMonth: 1,
          periodYear: 2024,
          isReversal: true,
          reversalOfId: 'c1',
          reversalReason: 'Duplicate entry',
          createdAt: regDate,
        ),
        // Valid payment of 50
        Contribution(
          id: 'c2',
          receiptNumber: 'REC-002',
          memberId: 'MEM-001',
          memberName: 'Reversal Member',
          amount: 50.0,
          date: regDate,
          recordedByUid: 't1',
          recordedByName: 'Treasurer',
          paymentMethod: PaymentMethod.telebirr,
          periodMonth: 2,
          periodYear: 2024,
          createdAt: regDate,
        ),
      ];

      final summary = calculator.calculateSummary(
        member: member,
        memberContributions: contributions,
        asOfDate: asOf,
      );

      expect(summary.totalPaid, 50.0);
      expect(summary.expectedDues, 150.0);
      expect(summary.arrears, 100.0);
      expect(summary.arrearsMonths, 2);
    });
  });
}
