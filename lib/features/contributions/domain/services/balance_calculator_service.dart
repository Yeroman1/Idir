import 'package:equatable/equatable.dart';

import '../../../members/domain/models/member.dart';
import '../models/contribution.dart';

class MemberFinancialSummary extends Equatable {
  const MemberFinancialSummary({
    required this.totalPaid,
    required this.expectedDues,
    required this.balance,
    required this.arrears,
    required this.arrearsMonths,
    required this.monthsActive,
  });

  final double totalPaid;
  final double expectedDues;
  final double balance;
  final double arrears;
  final int arrearsMonths;
  final int monthsActive;

  bool get isInArrears => arrears > 0;
  bool get hasPrepaidSurplus => balance > 0;

  @override
  List<Object?> get props => [
        totalPaid,
        expectedDues,
        balance,
        arrears,
        arrearsMonths,
        monthsActive,
      ];
}

class BalanceCalculatorService {
  const BalanceCalculatorService();

  /// Calculates the financial standing of a member based on their registered date,
  /// monthly dues rate, and recorded contribution ledger history.
  MemberFinancialSummary calculateSummary({
    required Member member,
    required List<Contribution> memberContributions,
    DateTime? asOfDate,
  }) {
    final asOf = asOfDate ?? DateTime.now();

    // 1. Calculate net contributions
    // Identify reversed original IDs to pair cancellations cleanly
    final reversedOriginalIds = <String>{};
    for (final c in memberContributions) {
      if (c.isReversal && c.reversalOfId != null) {
        reversedOriginalIds.add(c.reversalOfId!);
      }
    }

    double totalPaid = 0.0;
    for (final c in memberContributions) {
      if (c.isReversal) {
        // Standalone negative adjustments without a specific paired original
        if (c.reversalOfId == null) {
          totalPaid -= c.amount;
        }
        continue;
      }
      // If the contribution was reversed, exclude it from net paid
      if (c.isReversed || reversedOriginalIds.contains(c.id)) {
        continue;
      }
      totalPaid += c.amount;
    }

    if (totalPaid < 0) totalPaid = 0;

    // 2. Calculate months active since registration
    int monthsActive = (asOf.year - member.registeredAt.year) * 12 +
        (asOf.month - member.registeredAt.month) +
        1;
    if (monthsActive < 1) monthsActive = 1;

    // 3. Expected total dues
    final expectedDues = monthsActive * member.monthlyDues;

    // 4. Balance and arrears
    final net = totalPaid - expectedDues;
    final double balance = net;
    final double arrears = net < 0 ? -net : 0.0;
    final int arrearsMonths = member.monthlyDues > 0
        ? (arrears / member.monthlyDues).ceil()
        : 0;

    return MemberFinancialSummary(
      totalPaid: totalPaid,
      expectedDues: expectedDues,
      balance: balance,
      arrears: arrears,
      arrearsMonths: arrearsMonths,
      monthsActive: monthsActive,
    );
  }
}
