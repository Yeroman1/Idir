import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../contributions/presentation/providers/contributions_provider.dart';
import '../../../expenses/data/expenses_repository.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../data/report_data_service.dart';
import '../../domain/models/report_models.dart';
import '../../services/pdf_report_generator.dart';

final selectedReportTypeProvider =
    StateProvider<ReportType>((ref) => ReportType.monthlySummary);

final selectedReportMonthProvider =
    StateProvider<int>((ref) => DateTime.now().month);

final selectedReportYearProvider =
    StateProvider<int>((ref) => DateTime.now().year);

final selectedReportMemberIdProvider = StateProvider<String?>((ref) => null);

final pdfReportGeneratorProvider =
    Provider<PdfReportGenerator>((ref) => const PdfReportGenerator());

final monthlyReportDataProvider = Provider<MonthlyReportData?>((ref) {
  final service = ref.watch(reportDataServiceProvider);
  final members = ref.watch(membersStreamProvider).value ?? [];
  final contributions = ref.watch(contributionsStreamProvider).value ?? [];
  final expenses = ref.watch(expensesStreamProvider).value ?? [];

  final month = ref.watch(selectedReportMonthProvider);
  final year = ref.watch(selectedReportYearProvider);

  return service.generateMonthlyReport(
    month: month,
    year: year,
    members: members,
    contributions: contributions,
    expenses: expenses,
  );
});

final annualReportDataProvider = Provider<AnnualReportData?>((ref) {
  final service = ref.watch(reportDataServiceProvider);
  final members = ref.watch(membersStreamProvider).value ?? [];
  final contributions = ref.watch(contributionsStreamProvider).value ?? [];
  final expenses = ref.watch(expensesStreamProvider).value ?? [];

  final year = ref.watch(selectedReportYearProvider);

  return service.generateAnnualReport(
    year: year,
    members: members,
    contributions: contributions,
    expenses: expenses,
  );
});

final arrearsReportDataProvider = Provider<ArrearsReportData?>((ref) {
  final service = ref.watch(reportDataServiceProvider);
  final members = ref.watch(membersStreamProvider).value ?? [];
  final contributions = ref.watch(contributionsStreamProvider).value ?? [];

  return service.generateArrearsReport(
    members: members,
    contributions: contributions,
  );
});

final memberStatementDataProvider = Provider<MemberStatementData?>((ref) {
  final service = ref.watch(reportDataServiceProvider);
  final members = ref.watch(membersStreamProvider).value ?? [];
  final contributions = ref.watch(contributionsStreamProvider).value ?? [];
  final currentUser = ref.watch(currentUserProvider);
  final explicitMemberId = ref.watch(selectedReportMemberIdProvider);

  if (members.isEmpty) return null;

  // If regular member, strictly lock to their own memberId
  final targetMemberId = currentUser?.role == UserRole.member
      ? currentUser?.memberId
      : (explicitMemberId ?? members.first.id);

  final member = members.firstWhere(
    (m) => m.id == targetMemberId || m.memberId == targetMemberId,
    orElse: () => members.first,
  );

  return service.generateMemberStatement(
    member: member,
    contributions: contributions,
  );
});
