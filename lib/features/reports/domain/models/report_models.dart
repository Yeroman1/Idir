import 'package:equatable/equatable.dart';

import '../../../contributions/domain/models/contribution.dart';
import '../../../expenses/domain/models/expense.dart';
import '../../../members/domain/models/member.dart';

enum MemberStanding {
  inArrears,
  prepaid,
  upToDate,
}

enum ReportType {
  monthlySummary,
  annualBalanceSheet,
  arrearsReport,
  memberStatement,
}

extension ReportTypeX on ReportType {
  String get displayName => switch (this) {
        ReportType.monthlySummary => 'Monthly Financial Summary',
        ReportType.annualBalanceSheet => 'Annual Balance Sheet',
        ReportType.arrearsReport => 'Arrears & Defaulting Register',
        ReportType.memberStatement => 'Member Dues Statement',
      };
}

class MonthlyBreakdown extends Equatable {
  const MonthlyBreakdown({
    required this.month,
    required this.collected,
    required this.expenses,
    required this.net,
  });

  final int month;
  final double collected;
  final double expenses;
  final double net;

  @override
  List<Object?> get props => [month, collected, expenses, net];
}

class MonthlyReportData extends Equatable {
  const MonthlyReportData({
    required this.month,
    required this.year,
    required this.reportRef,
    required this.generatedAt,
    required this.totalActiveMembers,
    required this.duesExpected,
    required this.duesCollected,
    required this.collectionRate,
    required this.membersPaid,
    required this.membersInArrears,
    required this.totalClaimsDisbursed,
    required this.totalOperatingExpenses,
    required this.netChangeInFund,
    required this.transactions,
    required this.expenses,
  });

  final int month;
  final int year;
  final String reportRef;
  final DateTime generatedAt;
  final int totalActiveMembers;
  final double duesExpected;
  final double duesCollected;
  final double collectionRate;
  final int membersPaid;
  final int membersInArrears;
  final double totalClaimsDisbursed;
  final double totalOperatingExpenses;
  final double netChangeInFund;
  final List<Contribution> transactions;
  final List<Expense> expenses;

  @override
  List<Object?> get props => [
        month,
        year,
        reportRef,
        generatedAt,
        totalActiveMembers,
        duesExpected,
        duesCollected,
        collectionRate,
        membersPaid,
        membersInArrears,
        totalClaimsDisbursed,
        totalOperatingExpenses,
        netChangeInFund,
        transactions,
        expenses,
      ];
}

class AnnualReportData extends Equatable {
  const AnnualReportData({
    required this.year,
    required this.reportRef,
    required this.generatedAt,
    required this.grossContributions,
    required this.claimsDisbursed,
    required this.operationalExpenses,
    required this.netSurplus,
    required this.closingReserveFund,
    required this.monthlyBreakdown,
  });

  final int year;
  final String reportRef;
  final DateTime generatedAt;
  final double grossContributions;
  final double claimsDisbursed;
  final double operationalExpenses;
  final double netSurplus;
  final double closingReserveFund;
  final List<MonthlyBreakdown> monthlyBreakdown;

  @override
  List<Object?> get props => [
        year,
        reportRef,
        generatedAt,
        grossContributions,
        claimsDisbursed,
        operationalExpenses,
        netSurplus,
        closingReserveFund,
        monthlyBreakdown,
      ];
}

class ArrearsItem extends Equatable {
  const ArrearsItem({
    required this.memberId,
    required this.fullName,
    required this.phone,
    required this.monthlyDues,
    required this.monthsOverdue,
    required this.totalOwed,
  });

  final String memberId;
  final String fullName;
  final String phone;
  final double monthlyDues;
  final int monthsOverdue;
  final double totalOwed;

  @override
  List<Object?> get props => [
        memberId,
        fullName,
        phone,
        monthlyDues,
        monthsOverdue,
        totalOwed,
      ];
}

class ArrearsReportData extends Equatable {
  const ArrearsReportData({
    required this.reportRef,
    required this.generatedAt,
    required this.totalDefaultingMembers,
    required this.totalArrearsAmount,
    required this.items,
  });

  final String reportRef;
  final DateTime generatedAt;
  final int totalDefaultingMembers;
  final double totalArrearsAmount;
  final List<ArrearsItem> items;

  @override
  List<Object?> get props => [
        reportRef,
        generatedAt,
        totalDefaultingMembers,
        totalArrearsAmount,
        items,
      ];
}

class MemberStatementData extends Equatable {
  const MemberStatementData({
    required this.reportRef,
    required this.generatedAt,
    required this.member,
    required this.standing,
    required this.totalPaid,
    required this.balanceOrArrears,
    required this.monthsOverdue,
    required this.contributionsHistory,
  });

  final String reportRef;
  final DateTime generatedAt;
  final Member member;
  final MemberStanding standing;
  final double totalPaid;
  final double balanceOrArrears;
  final int monthsOverdue;
  final List<Contribution> contributionsHistory;

  @override
  List<Object?> get props => [
        reportRef,
        generatedAt,
        member,
        standing,
        totalPaid,
        balanceOrArrears,
        monthsOverdue,
        contributionsHistory,
      ];
}
