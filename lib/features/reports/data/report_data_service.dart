import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contributions/domain/models/contribution.dart';
import '../../contributions/domain/services/balance_calculator_service.dart';
import '../../expenses/domain/models/expense.dart';
import '../../members/domain/models/member.dart';
import '../domain/models/report_models.dart';

class ReportDataService {
  const ReportDataService({
    this.balanceService = const BalanceCalculatorService(),
  });

  final BalanceCalculatorService balanceService;

  MonthlyReportData generateMonthlyReport({
    required int month,
    required int year,
    required List<Member> members,
    required List<Contribution> contributions,
    required List<Expense> expenses,
  }) {
    final activeMembers =
        members.where((m) => m.status == MemberStatus.active).toList();
    final duesExpected = activeMembers.fold<double>(
      0.0,
      (sum, m) => sum + m.monthlyDues,
    );

    // Contributions for the specified period
    final periodContribs = contributions.where((c) {
      return c.periodMonth == month && c.periodYear == year;
    }).toList();

    double duesCollected = 0.0;
    final Set<String> paidMemberIds = {};

    for (final c in periodContribs) {
      if (c.isReversal) {
        duesCollected -= c.amount;
      } else if (!c.isReversed) {
        duesCollected += c.amount;
        paidMemberIds.add(c.memberId);
      }
    }
    if (duesCollected < 0) duesCollected = 0.0;

    final membersPaid = paidMemberIds.length;
    final membersInArrears =
        (activeMembers.length - membersPaid).clamp(0, activeMembers.length);

    final collectionRate = duesExpected > 0
        ? ((duesCollected / duesExpected) * 100.0).clamp(0.0, 100.0)
        : 0.0;

    // Expenses for the specified month and year
    final periodExpenses = expenses.where((e) {
      return e.createdAt.month == month && e.createdAt.year == year;
    }).toList();

    double totalClaimsDisbursed = 0.0;
    double totalOperatingExpenses = 0.0;

    for (final e in periodExpenses) {
      final amount =
          e.isReversal ? -e.amount : (e.isReversed ? 0.0 : e.amount);
      if (e.category == ExpenseCategory.payout) {
        totalClaimsDisbursed += amount;
      } else {
        totalOperatingExpenses += amount;
      }
    }

    if (totalClaimsDisbursed < 0) totalClaimsDisbursed = 0.0;
    if (totalOperatingExpenses < 0) totalOperatingExpenses = 0.0;

    final netChangeInFund =
        duesCollected - (totalClaimsDisbursed + totalOperatingExpenses);

    return MonthlyReportData(
      month: month,
      year: year,
      reportRef: 'REP-MTH-$year-${month.toString().padLeft(2, '0')}-001',
      generatedAt: DateTime.now(),
      totalActiveMembers: activeMembers.length,
      duesExpected: duesExpected,
      duesCollected: duesCollected,
      collectionRate: collectionRate,
      membersPaid: membersPaid,
      membersInArrears: membersInArrears,
      totalClaimsDisbursed: totalClaimsDisbursed,
      totalOperatingExpenses: totalOperatingExpenses,
      netChangeInFund: netChangeInFund,
      transactions: periodContribs,
      expenses: periodExpenses,
    );
  }

  AnnualReportData generateAnnualReport({
    required int year,
    required List<Member> members,
    required List<Contribution> contributions,
    required List<Expense> expenses,
  }) {
    double grossContributions = 0.0;
    double claimsDisbursed = 0.0;
    double operationalExpenses = 0.0;
    final List<MonthlyBreakdown> breakdowns = [];

    for (int m = 1; m <= 12; m++) {
      double mCollected = 0.0;
      for (final c in contributions) {
        if (c.periodYear == year && c.periodMonth == m) {
          if (c.isReversal) {
            mCollected -= c.amount;
          } else if (!c.isReversed) {
            mCollected += c.amount;
          }
        }
      }
      if (mCollected < 0) mCollected = 0.0;

      double mExpenses = 0.0;
      for (final e in expenses) {
        if (e.createdAt.year == year && e.createdAt.month == m) {
          final amt =
              e.isReversal ? -e.amount : (e.isReversed ? 0.0 : e.amount);
          mExpenses += amt;
        }
      }
      if (mExpenses < 0) mExpenses = 0.0;

      breakdowns.add(MonthlyBreakdown(
        month: m,
        collected: mCollected,
        expenses: mExpenses,
        net: mCollected - mExpenses,
      ));
    }

    for (final c in contributions) {
      if (c.periodYear == year) {
        if (c.isReversal) {
          grossContributions -= c.amount;
        } else if (!c.isReversed) {
          grossContributions += c.amount;
        }
      }
    }
    if (grossContributions < 0) grossContributions = 0.0;

    for (final e in expenses) {
      if (e.createdAt.year == year) {
        final amt =
            e.isReversal ? -e.amount : (e.isReversed ? 0.0 : e.amount);
        if (e.category == ExpenseCategory.payout) {
          claimsDisbursed += amt;
        } else {
          operationalExpenses += amt;
        }
      }
    }
    if (claimsDisbursed < 0) claimsDisbursed = 0.0;
    if (operationalExpenses < 0) operationalExpenses = 0.0;

    final netSurplus =
        grossContributions - (claimsDisbursed + operationalExpenses);

    // Total reserve fund all-time (Rule 3)
    double allTimeContribs = 0.0;
    for (final c in contributions) {
      if (c.isReversal) {
        allTimeContribs -= c.amount;
      } else if (!c.isReversed) {
        allTimeContribs += c.amount;
      }
    }
    double allTimeExpenses = 0.0;
    for (final e in expenses) {
      final amt =
          e.isReversal ? -e.amount : (e.isReversed ? 0.0 : e.amount);
      allTimeExpenses += amt;
    }
    final closingReserveFund = allTimeContribs - allTimeExpenses;

    return AnnualReportData(
      year: year,
      reportRef: 'REP-ANN-$year-001',
      generatedAt: DateTime.now(),
      grossContributions: grossContributions,
      claimsDisbursed: claimsDisbursed,
      operationalExpenses: operationalExpenses,
      netSurplus: netSurplus,
      closingReserveFund: closingReserveFund,
      monthlyBreakdown: breakdowns,
    );
  }

  ArrearsReportData generateArrearsReport({
    required List<Member> members,
    required List<Contribution> contributions,
  }) {
    final activeMembers =
        members.where((m) => m.status == MemberStatus.active).toList();
    final List<ArrearsItem> items = [];
    double totalArrearsAmount = 0.0;

    for (final m in activeMembers) {
      final memberContribs = contributions
          .where((c) => c.memberId == m.id || c.memberId == m.memberId)
          .toList();
      final summary = balanceService.calculateSummary(
        member: m,
        memberContributions: memberContribs,
      );

      if (summary.isInArrears && summary.arrearsMonths > 0) {
        items.add(ArrearsItem(
          memberId: m.memberId,
          fullName: m.fullName,
          phone: m.phone,
          monthlyDues: m.monthlyDues,
          monthsOverdue: summary.arrearsMonths,
          totalOwed: summary.arrears,
        ));
        totalArrearsAmount += summary.arrears;
      }
    }

    // Sort by largest debt first
    items.sort((a, b) => b.totalOwed.compareTo(a.totalOwed));

    final now = DateTime.now();
    return ArrearsReportData(
      reportRef:
          'REP-ARR-${now.year}-${now.month.toString().padLeft(2, '0')}-001',
      generatedAt: now,
      totalDefaultingMembers: items.length,
      totalArrearsAmount: totalArrearsAmount,
      items: items,
    );
  }

  MemberStatementData generateMemberStatement({
    required Member member,
    required List<Contribution> contributions,
  }) {
    final targetId = member.id;
    final targetMemberId = member.memberId;
    final memberContribs = contributions
        .whereType<Contribution>()
        .where((c) => c.memberId == targetId || c.memberId == targetMemberId)
        .toList();
    memberContribs.sort((a, b) => b.date.compareTo(a.date));

    final summary = balanceService.calculateSummary(
      member: member,
      memberContributions: memberContribs,
    );

    final standing = summary.isInArrears
        ? MemberStanding.inArrears
        : (summary.hasPrepaidSurplus
            ? MemberStanding.prepaid
            : MemberStanding.upToDate);

    final balanceOrArrears =
        summary.isInArrears ? summary.arrears : summary.balance;

    return MemberStatementData(
      reportRef: 'REP-STM-${member.memberId}',
      generatedAt: DateTime.now(),
      member: member,
      standing: standing,
      totalPaid: summary.totalPaid,
      balanceOrArrears: balanceOrArrears,
      monthsOverdue: summary.arrearsMonths,
      contributionsHistory: memberContribs,
    );
  }
}

final reportDataServiceProvider = Provider<ReportDataService>((ref) {
  return const ReportDataService();
});
