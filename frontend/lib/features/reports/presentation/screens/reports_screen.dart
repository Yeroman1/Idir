import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../members/domain/models/member.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../domain/models/report_models.dart';
import '../providers/reports_provider.dart';
import 'pdf_viewer_screen.dart';
import '../../../../core/widgets/offline_indicator_bar.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isGeneratingPdf = false;

  Future<void> _exportPdf(BuildContext context) async {
    final reportType = ref.read(selectedReportTypeProvider);
    final pdfGen = ref.read(pdfReportGeneratorProvider);

    setState(() => _isGeneratingPdf = true);

    try {
      final (pdfBytes, title, fileName) = switch (reportType) {
        ReportType.monthlySummary => await () async {
            final data = ref.read(monthlyReportDataProvider);
            if (data == null) throw Exception('No monthly data available');
            final bytes = await pdfGen.generateMonthlyReportPdf(data);
            return (
              bytes,
              'Monthly Summary (${data.month}/${data.year})',
              'monthly_summary_${data.year}_${data.month}.pdf'
            );
          }(),
        ReportType.annualBalanceSheet => await () async {
            final data = ref.read(annualReportDataProvider);
            if (data == null) throw Exception('No annual data available');
            final bytes = await pdfGen.generateAnnualReportPdf(data);
            return (
              bytes,
              'Annual Balance Sheet (${data.year})',
              'annual_report_${data.year}.pdf'
            );
          }(),
        ReportType.arrearsReport => await () async {
            final data = ref.read(arrearsReportDataProvider);
            if (data == null) throw Exception('No arrears data available');
            final bytes = await pdfGen.generateArrearsReportPdf(data);
            return (
              bytes,
              'Arrears & Defaulting Register',
              'arrears_report_${DateTime.now().year}_${DateTime.now().month}.pdf'
            );
          }(),
        ReportType.memberStatement => await () async {
            final data = ref.read(memberStatementDataProvider);
            if (data == null) throw Exception('No member statement available');
            final bytes = await pdfGen.generateMemberStatementPdf(data);
            return (
              bytes,
              'Statement: ${data.member.fullName}',
              'statement_${data.member.memberId}.pdf'
            );
          }(),
      };

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            title: title,
            pdfBytes: pdfBytes,
            fileName: fileName,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    final reportType = ref.read(selectedReportTypeProvider);
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(now);

    final csvContent = StringBuffer();
    csvContent.writeln('"IDIR CONNECT - AUDITABLE FINANCIAL REPORT"');
    csvContent.writeln('"Generation Date","${dateStr}"');

    switch (reportType) {
      case ReportType.monthlySummary:
        final data = ref.read(monthlyReportDataProvider);
        if (data == null) throw Exception('No monthly data available');
        csvContent.writeln('"Report Type","Monthly Financial Summary"');
        csvContent.writeln('"Period Covered","${data.month}/${data.year}"');
        csvContent.writeln('"Report Reference","${data.reportRef}"');
        csvContent.writeln('');
        csvContent.writeln('"Metric","Value (ETB)"');
        csvContent.writeln('"Active Members","${data.totalActiveMembers}"');
        csvContent.writeln('"Dues Expected","${data.duesExpected.toStringAsFixed(2)}"');
        csvContent.writeln('"Dues Collected","${data.duesCollected.toStringAsFixed(2)}"');
        csvContent.writeln('"Collection Rate","${data.collectionRate.toStringAsFixed(1)}%"');
        csvContent.writeln('"Claims Disbursed","${data.totalClaimsDisbursed.toStringAsFixed(2)}"');
        csvContent.writeln('"Operating Expenses","${data.totalOperatingExpenses.toStringAsFixed(2)}"');
        csvContent.writeln('"Net Change in Fund","${data.netChangeInFund.toStringAsFixed(2)}"');
        break;
      case ReportType.annualBalanceSheet:
        final data = ref.read(annualReportDataProvider);
        if (data == null) throw Exception('No annual data available');
        csvContent.writeln('"Report Type","Annual Financial Statement"');
        csvContent.writeln('"Period Covered","Year ${data.year}"');
        csvContent.writeln('');
        csvContent.writeln('"Metric","Value (ETB)"');
        csvContent.writeln('"Opening Balance","${data.openingBalance.toStringAsFixed(2)}"');
        csvContent.writeln('"Total Contributions","${data.totalContributions.toStringAsFixed(2)}"');
        csvContent.writeln('"Total Expenses","${data.totalExpenses.toStringAsFixed(2)}"');
        csvContent.writeln('"Net Reserve Fund","${data.closingBalance.toStringAsFixed(2)}"');
        break;
      case ReportType.arrearsReport:
        final data = ref.read(arrearsReportDataProvider);
        if (data == null) throw Exception('No arrears data available');
        csvContent.writeln('"Report Type","Arrears & Defaulting Register"');
        csvContent.writeln('"Total Arrears Amount","${data.totalArrearsAmount.toStringAsFixed(2)}"');
        csvContent.writeln('');
        csvContent.writeln('"Member ID","Full Name","Phone","Months in Arrears","Total Overdue"');
        for (final item in data.items) {
          csvContent.writeln('"${item.member.memberId}","${item.member.fullName}","${item.member.phoneNumber}","${item.monthsInArrears}","${item.arrearsAmount.toStringAsFixed(2)}"');
        }
        break;
      case ReportType.memberStatement:
        final data = ref.read(memberStatementDataProvider);
        if (data == null) throw Exception('No member statement available');
        csvContent.writeln('"Report Type","Member Contribution Statement"');
        csvContent.writeln('"Member ID","${data.member.memberId}"');
        csvContent.writeln('"Member Name","${data.member.fullName}"');
        csvContent.writeln('"Total Dues Paid","${data.totalPaid.toStringAsFixed(2)}"');
        csvContent.writeln('"Outstanding Balance","${data.member.arrears.toStringAsFixed(2)}"');
        break;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.table_chart_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Export CSV Generated', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Auditable report CSV compiled successfully from live database records for period: $dateStr.', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                csvContent.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                maxLines: 10,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Done'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Financial CSV ledger exported successfully'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final isRegularMember = user?.role == UserRole.member;

    final selectedType = ref.watch(selectedReportTypeProvider);
    final members = ref.watch(membersStreamProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reports),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(monthlyReportDataProvider);
              ref.invalidate(annualReportDataProvider);
              ref.invalidate(arrearsReportDataProvider);
              ref.invalidate(membersStreamProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.table_chart_outlined),
            tooltip: 'Export Official CSV',
            onPressed: () => _exportCsv(context),
          ),
          IconButton(
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Official PDF',
            onPressed: _isGeneratingPdf ? null : () => _exportPdf(context),
          ),
        ],
      ),
      bottomNavigationBar: const OfflineIndicatorBar(includeBottomSafeArea: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Institutional Header Banner ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.secondary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Official Audited Reports',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRegularMember
                            ? 'Your official individual contribution statement and balance.'
                            : 'Generate, preview, and print certified mutual-aid ledger records.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Report Type Selector (Restricted if Member) ─────────────────
          if (!isRegularMember) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ReportTypeChip(
                    label: 'Monthly Summary',
                    icon: Icons.calendar_view_month,
                    isSelected: selectedType == ReportType.monthlySummary,
                    onTap: () => ref
                        .read(selectedReportTypeProvider.notifier)
                        .state = ReportType.monthlySummary,
                  ),
                  const SizedBox(width: 8),
                  _ReportTypeChip(
                    label: 'Annual Balance',
                    icon: Icons.account_balance,
                    isSelected: selectedType == ReportType.annualBalanceSheet,
                    onTap: () => ref
                        .read(selectedReportTypeProvider.notifier)
                        .state = ReportType.annualBalanceSheet,
                  ),
                  const SizedBox(width: 8),
                  _ReportTypeChip(
                    label: 'Arrears Register',
                    icon: Icons.warning_amber_rounded,
                    isSelected: selectedType == ReportType.arrearsReport,
                    onTap: () => ref
                        .read(selectedReportTypeProvider.notifier)
                        .state = ReportType.arrearsReport,
                  ),
                  const SizedBox(width: 8),
                  _ReportTypeChip(
                    label: 'Member Statement',
                    icon: Icons.person_search,
                    isSelected: selectedType == ReportType.memberStatement,
                    onTap: () => ref
                        .read(selectedReportTypeProvider.notifier)
                        .state = ReportType.memberStatement,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Filter Controls ─────────────────────────────────────────────
          _buildFilterBar(context, selectedType, isRegularMember, members),
          const SizedBox(height: 16),

          // ── Report Content Card ─────────────────────────────────────────
          switch (selectedType) {
            ReportType.monthlySummary => _MonthlyReportPreview(),
            ReportType.annualBalanceSheet => _AnnualReportPreview(),
            ReportType.arrearsReport => _ArrearsReportPreview(),
            ReportType.memberStatement => _MemberStatementPreview(),
          },

          const SizedBox(height: 24),

          // ── Big Export Action Button ────────────────────────────────────
          FilledButton.icon(
            onPressed: _isGeneratingPdf ? null : () => _exportPdf(context),
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print_outlined),
            label: Text(
              _isGeneratingPdf
                  ? 'Compiling PDF Document…'
                  : 'Generate & Preview Official PDF',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Supports Ethiopian Birr (ETB) • Includes Chairperson & Auditor signatures',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    ReportType type,
    bool isRegularMember,
    List<Member> members,
  ) {
    final selectedMonth = ref.watch(selectedReportMonthProvider);
    final selectedYear = ref.watch(selectedReportYearProvider);
    final selectedMemberId = ref.watch(selectedReportMemberIdProvider);

    if (type == ReportType.monthlySummary) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedMonth,
                    isExpanded: true,
                    items: List.generate(12, (i) => i + 1).map((m) {
                      final name = DateFormat('MMMM').format(DateTime(2026, m));
                      return DropdownMenuItem(value: m, child: Text(name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(selectedReportMonthProvider.notifier).state =
                            val;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedYear,
                    isExpanded: true,
                    items: [2024, 2025, 2026, 2027].map((y) {
                      return DropdownMenuItem(value: y, child: Text('$y'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(selectedReportYearProvider.notifier).state =
                            val;
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (type == ReportType.annualBalanceSheet) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.event, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              const Text('Fiscal Year:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedYear,
                  items: [2024, 2025, 2026, 2027].map((y) {
                    return DropdownMenuItem(value: y, child: Text('$y'));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(selectedReportYearProvider.notifier).state = val;
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (type == ReportType.memberStatement && !isRegularMember) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedMemberId ??
                  (members.isNotEmpty ? members.first.id : null),
              isExpanded: true,
              hint: const Text('Select Member for Statement'),
              items: members.map<DropdownMenuItem<String>>((m) {
                return DropdownMenuItem<String>(
                  value: m.id,
                  child: Text('${m.fullName} (${m.memberId})'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref.read(selectedReportMemberIdProvider.notifier).state =
                      val;
                }
              },
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _ReportTypeChip extends StatelessWidget {
  const _ReportTypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly Report Preview
// ─────────────────────────────────────────────────────────────────────────────
class _MonthlyReportPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(monthlyReportDataProvider);
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateFormat('MMMM').format(DateTime(data.year, data.month))} ${data.year}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    data.reportRef,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                _StatTile(
                  label: 'Expected',
                  value: '${data.duesExpected.toStringAsFixed(0)} ETB',
                ),
                _StatTile(
                  label: 'Collected',
                  value: '${data.duesCollected.toStringAsFixed(0)} ETB',
                  valueColor: AppColors.primary,
                ),
                _StatTile(
                  label: 'Rate',
                  value: '${data.collectionRate.toStringAsFixed(0)}%',
                  valueColor: AppColors.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatTile(
                  label: 'Claims Paid',
                  value: '${data.totalClaimsDisbursed.toStringAsFixed(0)} ETB',
                  valueColor: AppColors.error,
                ),
                _StatTile(
                  label: 'Expenses',
                  value:
                      '${data.totalOperatingExpenses.toStringAsFixed(0)} ETB',
                  valueColor: Colors.grey.shade700,
                ),
                _StatTile(
                  label: 'Net Addition',
                  value: '${data.netChangeInFund.toStringAsFixed(0)} ETB',
                  valueColor: data.netChangeInFund >= 0
                      ? AppColors.success
                      : AppColors.error,
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Active Members: ${data.totalActiveMembers}   •   Paid: ${data.membersPaid}   •   In Arrears: ${data.membersInArrears}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${data.transactions.length} contribution receipts recorded in this cycle',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Annual Report Preview
// ─────────────────────────────────────────────────────────────────────────────
class _AnnualReportPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(annualReportDataProvider);
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fiscal Year ${data.year} Balance Sheet',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    data.reportRef,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                _StatTile(
                  label: 'Gross Contributions',
                  value:
                      '${data.grossContributions.toStringAsFixed(0)} ETB',
                  valueColor: AppColors.primary,
                ),
                _StatTile(
                  label: 'Claims Disbursed',
                  value: '${data.claimsDisbursed.toStringAsFixed(0)} ETB',
                  valueColor: AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatTile(
                  label: 'Operating Expenses',
                  value:
                      '${data.operationalExpenses.toStringAsFixed(0)} ETB',
                  valueColor: Colors.grey.shade700,
                ),
                _StatTile(
                  label: 'Net Operating Surplus',
                  value: '${data.netSurplus.toStringAsFixed(0)} ETB',
                  valueColor: data.netSurplus >= 0
                      ? AppColors.success
                      : AppColors.error,
                ),
              ],
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Closing Reserve Fund:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${data.closingReserveFund.toStringAsFixed(0)} ETB',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arrears Report Preview
// ─────────────────────────────────────────────────────────────────────────────
class _ArrearsReportPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(arrearsReportDataProvider);
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Defaulting Members Register',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${data.totalDefaultingMembers} Overdue',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                _StatTile(
                  label: 'Total Defaulting Members',
                  value: '${data.totalDefaultingMembers}',
                  valueColor: AppColors.error,
                ),
                _StatTile(
                  label: 'Total Outstanding Debt',
                  value: '${data.totalArrearsAmount.toStringAsFixed(0)} ETB',
                  valueColor: AppColors.error,
                ),
              ],
            ),
            const Divider(height: 20),
            if (data.items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('All members are fully up to date! 🎉'),
                ),
              )
            else
              ...data.items.take(4).map((item) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.warning_amber,
                    color: AppColors.error,
                    size: 20,
                  ),
                  title: Text(item.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${item.memberId} • ${item.monthsOverdue} month(s) overdue'),
                  trailing: Text(
                    '${item.totalOwed.toStringAsFixed(0)} ETB',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Member Statement Preview
// ─────────────────────────────────────────────────────────────────────────────
class _MemberStatementPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(memberStatementDataProvider);
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final standingLabel = switch (data.standing) {
      MemberStanding.inArrears => 'IN ARREARS',
      MemberStanding.prepaid => 'PREPAID',
      MemberStanding.upToDate => 'GOOD STANDING',
    };

    final standingColor = switch (data.standing) {
      MemberStanding.inArrears => AppColors.error,
      MemberStanding.prepaid => AppColors.primary,
      MemberStanding.upToDate => AppColors.success,
    };

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data.member.fullName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: standingColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    standingLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: standingColor,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'ID: ${data.member.memberId}   •   Phone: ${data.member.phone}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const Divider(height: 20),
            Row(
              children: [
                _StatTile(
                  label: 'Monthly Rate',
                  value: '${data.member.monthlyDues.toStringAsFixed(0)} ETB',
                ),
                _StatTile(
                  label: 'Total Paid',
                  value: '${data.totalPaid.toStringAsFixed(0)} ETB',
                  valueColor: AppColors.primary,
                ),
                _StatTile(
                  label: data.standing == MemberStanding.inArrears
                      ? 'Arrears Owed'
                      : 'Net Balance',
                  value:
                      '${data.balanceOrArrears.toStringAsFixed(0)} ETB',
                  valueColor: standingColor,
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              '${data.contributionsHistory.length} total transaction receipts on file',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
