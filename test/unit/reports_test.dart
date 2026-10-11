import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/features/contributions/domain/models/contribution.dart';
import 'package:idir_app/features/expenses/domain/models/expense.dart';
import 'package:idir_app/features/members/domain/models/member.dart';
import 'package:idir_app/features/reports/data/report_data_service.dart';
import 'package:idir_app/features/reports/domain/models/report_models.dart';
import 'package:idir_app/features/reports/services/pdf_report_generator.dart';

void main() {
  group('ReportDataService Unit Tests', () {
    late ReportDataService service;
    late List<Member> members;
    late List<Contribution> contributions;
    late List<Expense> expenses;

    setUp(() {
      service = const ReportDataService();

      final regDate = DateTime(2026, 1, 1);
      members = [
        Member(
          id: 'mem_01',
          memberId: 'MEM-001',
          fullName: 'Abebe Bikila',
          phone: '+251911000001',
          monthlyDues: 200.0,
          registeredAt: regDate,
          status: MemberStatus.active,
          createdAt: regDate,
          updatedAt: regDate,
        ),
        Member(
          id: 'mem_02',
          memberId: 'MEM-002',
          fullName: 'Fatuma Mohammed',
          phone: '+251911000002',
          monthlyDues: 200.0,
          registeredAt: regDate,
          status: MemberStatus.active,
          createdAt: regDate,
          updatedAt: regDate,
        ),
        Member(
          id: 'mem_03',
          memberId: 'MEM-003',
          fullName: 'Chaltu Bekele',
          phone: '+251911000003',
          monthlyDues: 300.0,
          registeredAt: regDate,
          status: MemberStatus.suspended, // Suspended member
          createdAt: regDate,
          updatedAt: regDate,
        ),
      ];

      contributions = [
        // Member 1 paid for Oct 2026
        Contribution(
          id: 'con_01',
          receiptNumber: 'REC-2026-001',
          memberId: 'MEM-001',
          memberName: 'Abebe Bikila',
          amount: 200.0,
          date: DateTime(2026, 10, 5),
          recordedByUid: 'user_treasurer',
          recordedByName: 'Chaltu Bekele',
          paymentMethod: PaymentMethod.telebirr,
          periodMonth: 10,
          periodYear: 2026,
          createdAt: DateTime(2026, 10, 5),
        ),
        // Member 1 also paid for Nov 2026 (prepaid)
        Contribution(
          id: 'con_02',
          receiptNumber: 'REC-2026-002',
          memberId: 'MEM-001',
          memberName: 'Abebe Bikila',
          amount: 200.0,
          date: DateTime(2026, 10, 5),
          recordedByUid: 'user_treasurer',
          recordedByName: 'Chaltu Bekele',
          paymentMethod: PaymentMethod.cbeBirr,
          periodMonth: 11,
          periodYear: 2026,
          createdAt: DateTime(2026, 10, 5),
        ),
      ];

      expenses = [
        Expense(
          id: 'exp_01',
          voucherNumber: 'EXP-2026-001',
          category: ExpenseCategory.payout,
          amount: 5000.0,
          description: 'Bereavement assistance payout',
          claimId: 'claim_001',
          recordedByUid: 'user_treasurer',
          recordedByName: 'Treasurer',
          createdAt: DateTime(2026, 10, 6),
        ),
        Expense(
          id: 'exp_02',
          voucherNumber: 'EXP-2026-002',
          category: ExpenseCategory.administrative,
          amount: 300.0,
          description: 'Printing receipt booklets',
          recordedByUid: 'user_treasurer',
          recordedByName: 'Treasurer',
          createdAt: DateTime(2026, 10, 7),
        ),
      ];
    });

    test('generateMonthlyReport calculates dues, collections, and net change', () {
      final report = service.generateMonthlyReport(
        month: 10,
        year: 2026,
        members: members,
        contributions: contributions,
        expenses: expenses,
      );

      // Active members: MEM-001 (200) + MEM-002 (200) = 400 ETB expected
      expect(report.totalActiveMembers, equals(2));
      expect(report.duesExpected, equals(400.0));

      // In Oct 2026: only con_01 belongs to period 10/2026 = 200 ETB
      expect(report.duesCollected, equals(200.0));
      expect(report.collectionRate, equals(50.0));
      expect(report.membersPaid, equals(1));
      expect(report.membersInArrears, equals(1));

      // Expenses in Oct 2026: 5000 payout + 300 administrative
      expect(report.totalClaimsDisbursed, equals(5000.0));
      expect(report.totalOperatingExpenses, equals(300.0));

      // Net change = 200 - (5000 + 300) = -5100 ETB
      expect(report.netChangeInFund, equals(-5100.0));
      expect(report.reportRef, equals('REP-MTH-2026-10-001'));
    });

    test('generateAnnualReport calculates 12-month breakdown and Rule 3 reserve fund', () {
      final report = service.generateAnnualReport(
        year: 2026,
        members: members,
        contributions: contributions,
        expenses: expenses,
      );

      expect(report.year, equals(2026));
      expect(report.reportRef, equals('REP-ANN-2026-001'));
      // Gross contributions in 2026: 200 + 200 = 400 ETB
      expect(report.grossContributions, equals(400.0));
      expect(report.claimsDisbursed, equals(5000.0));
      expect(report.operationalExpenses, equals(300.0));

      // Net surplus = 400 - 5300 = -4900 ETB
      expect(report.netSurplus, equals(-4900.0));

      // 12 monthly breakdowns
      expect(report.monthlyBreakdown.length, equals(12));
      final octBreakdown =
          report.monthlyBreakdown.firstWhere((b) => b.month == 10);
      expect(octBreakdown.collected, equals(200.0));
      expect(octBreakdown.expenses, equals(5300.0));
    });

    test('generateArrearsReport accurately flags defaulting members', () {
      final report = service.generateArrearsReport(
        members: members,
        contributions: contributions,
      );

      // MEM-002 has 0 contributions, so should be in arrears
      expect(report.totalDefaultingMembers, greaterThanOrEqualTo(1));
      expect(report.items.any((item) => item.memberId == 'MEM-002'), isTrue);
      final mem2Item =
          report.items.firstWhere((i) => i.memberId == 'MEM-002');
      expect(mem2Item.totalOwed, greaterThan(0));
      expect(report.totalArrearsAmount, greaterThan(0));
    });

    test('generateMemberStatement captures history and standing', () {
      final mem1 = members.firstWhere((m) => m.memberId == 'MEM-001');
      final statement = service.generateMemberStatement(
        member: mem1,
        contributions: contributions,
      );

      expect(statement.member.memberId, equals('MEM-001'));
      expect(statement.reportRef, equals('REP-STM-MEM-001'));
      expect(statement.contributionsHistory.length, equals(2));
      expect(statement.totalPaid, equals(400.0));
    });
  });

  group('PdfReportGenerator Unit Tests', () {
    const generator = PdfReportGenerator();
    final regDate = DateTime(2026, 1, 1);
    final member = Member(
      id: 'mem_01',
      memberId: 'MEM-001',
      fullName: 'Abebe Bikila',
      phone: '+251911000001',
      monthlyDues: 200.0,
      registeredAt: regDate,
      status: MemberStatus.active,
      createdAt: regDate,
      updatedAt: regDate,
    );

    test('generateMonthlyReportPdf produces valid PDF bytes', () async {
      final data = MonthlyReportData(
        month: 10,
        year: 2026,
        reportRef: 'REP-MTH-2026-10-001',
        generatedAt: DateTime.now(),
        totalActiveMembers: 50,
        duesExpected: 10000.0,
        duesCollected: 9600.0,
        collectionRate: 96.0,
        membersPaid: 48,
        membersInArrears: 2,
        totalClaimsDisbursed: 5000.0,
        totalOperatingExpenses: 500.0,
        netChangeInFund: 4100.0,
        transactions: const [],
        expenses: const [],
      );

      final pdfBytes = await generator.generateMonthlyReportPdf(data);
      expect(pdfBytes.isNotEmpty, isTrue);
      // PDF documents start with %PDF- (hex 25 50 44 46 2d)
      final headerStr = latin1.decode(pdfBytes.sublist(0, 5));
      expect(headerStr, equals('%PDF-'));
    });

    test('generateAnnualReportPdf produces valid PDF bytes', () async {
      final data = AnnualReportData(
        year: 2026,
        reportRef: 'REP-ANN-2026-001',
        generatedAt: DateTime.now(),
        grossContributions: 120000.0,
        claimsDisbursed: 35000.0,
        operationalExpenses: 12000.0,
        netSurplus: 73000.0,
        closingReserveFund: 185000.0,
        monthlyBreakdown: List.generate(
          12,
          (i) => MonthlyBreakdown(
            month: i + 1,
            collected: 10000.0,
            expenses: 3916.6,
            net: 6083.4,
          ),
        ),
      );

      final pdfBytes = await generator.generateAnnualReportPdf(data);
      expect(pdfBytes.isNotEmpty, isTrue);
      final headerStr = latin1.decode(pdfBytes.sublist(0, 5));
      expect(headerStr, equals('%PDF-'));
    });

    test('generateArrearsReportPdf produces valid PDF bytes', () async {
      final data = ArrearsReportData(
        reportRef: 'REP-ARR-2026-10-001',
        generatedAt: DateTime.now(),
        totalDefaultingMembers: 2,
        totalArrearsAmount: 1200.0,
        items: const [
          ArrearsItem(
            memberId: 'MEM-005',
            fullName: 'Dawit Kebede',
            phone: '+251911223344',
            monthlyDues: 200.0,
            monthsOverdue: 3,
            totalOwed: 600.0,
          ),
          ArrearsItem(
            memberId: 'MEM-008',
            fullName: 'Sara Tesfaye',
            phone: '+251911334455',
            monthlyDues: 200.0,
            monthsOverdue: 3,
            totalOwed: 600.0,
          ),
        ],
      );

      final pdfBytes = await generator.generateArrearsReportPdf(data);
      expect(pdfBytes.isNotEmpty, isTrue);
      final headerStr = latin1.decode(pdfBytes.sublist(0, 5));
      expect(headerStr, equals('%PDF-'));
    });

    test('generateMemberStatementPdf produces valid PDF bytes', () async {
      final data = MemberStatementData(
        reportRef: 'REP-STM-MEM-001',
        generatedAt: DateTime.now(),
        member: member,
        standing: MemberStanding.inArrears,
        totalPaid: 1600.0,
        balanceOrArrears: 400.0,
        monthsOverdue: 2,
        contributionsHistory: const [],
      );

      final pdfBytes = await generator.generateMemberStatementPdf(data);
      expect(pdfBytes.isNotEmpty, isTrue);
      final headerStr = latin1.decode(pdfBytes.sublist(0, 5));
      expect(headerStr, equals('%PDF-'));
    });
  });

  group('Reports Institutional Role Access Matrix', () {
    test(
        'canViewAllFinances enables Chairperson, Treasurer, and Auditor to inspect full reports',
        () {
      expect(UserRole.chairperson.canViewAllFinances, isTrue);
      expect(UserRole.treasurer.canViewAllFinances, isTrue);
      expect(UserRole.auditor.canViewAllFinances, isTrue);
      expect(UserRole.member.canViewAllFinances, isFalse);
    });

    test(
        'canViewOwnBalance enables regular members to access their own dues statement',
        () {
      expect(UserRole.member.canViewOwnBalance, isTrue);
    });
  });
}
