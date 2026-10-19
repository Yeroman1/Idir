import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models/report_models.dart';

class PdfReportGenerator {
  const PdfReportGenerator();

  static const PdfColor primaryColor = PdfColor.fromInt(0xFF1A6B5A);
  static const PdfColor accentColor = PdfColor.fromInt(0xFFD4821A);
  static const PdfColor lightBg = PdfColor.fromInt(0xFFF7F9F8);
  static const PdfColor darkText = PdfColor.fromInt(0xFF1F2937);
  static const PdfColor mutedText = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor dangerColor = PdfColor.fromInt(0xFFC62828);
  static const PdfColor successColor = PdfColor.fromInt(0xFF2E7D32);

  Future<pw.ThemeData> _loadTheme() async {
    try {
      final regularData =
          await rootBundle.load('assets/fonts/NotoSansEthiopic-Regular.ttf');
      final boldData =
          await rootBundle.load('assets/fonts/NotoSansEthiopic-Bold.ttf');
      final regular = pw.Font.ttf(regularData);
      final bold = pw.Font.ttf(boldData);
      return pw.ThemeData.withFont(base: regular, bold: bold);
    } catch (_) {
      return pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }

  pw.Widget _buildHeader({
    required String title,
    required String subtitle,
    required String reportRef,
    required DateTime date,
  }) {
    final df = DateFormat('dd MMM yyyy, HH:mm');
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        color: lightBg,
        border: pw.Border(
          left: pw.BorderSide(color: primaryColor, width: 4),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TINSAE MUTUAL AID ASSOCIATION',
                style: const pw.TextStyle(
                  fontSize: 14,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                title,
                style: const pw.TextStyle(
                  fontSize: 16,
                  color: darkText,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                subtitle,
                style: const pw.TextStyle(fontSize: 10, color: mutedText),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Text(
                  reportRef,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Date: ${df.format(date)}',
                style: const pw.TextStyle(fontSize: 9, color: mutedText),
              ),
              pw.Text(
                'Institutional Ledger Record',
                style: const pw.TextStyle(fontSize: 8, color: mutedText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatures() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 24),
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderColor)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 140,
                height: 36,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: darkText)),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Prepared / Certified By',
                  style: const pw.TextStyle(fontSize: 9, color: mutedText)),
              pw.Text('Chairperson / ሰብሳቢ',
                  style: const pw.TextStyle(
                      fontSize: 10)),
            ],
          ),
          pw.Container(
            width: 70,
            height: 50,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Center(
              child: pw.Text(
                'OFFICIAL\nSEAL\nማኅተም',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7, color: mutedText),
              ),
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                width: 140,
                height: 36,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: darkText)),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Audited / Verified By',
                  style: const pw.TextStyle(fontSize: 9, color: mutedText)),
              pw.Text('Treasurer / Auditor / ገንዘብ ያዥ',
                  style: const pw.TextStyle(
                      fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // ── 1. Monthly Summary Report PDF ──────────────────────────────────────────
  Future<Uint8List> generateMonthlyReportPdf(MonthlyReportData data) async {
    final pdf = pw.Document();
    final theme = await _loadTheme();
    final dfDate = DateFormat('dd/MM/yyyy');
    final monthName =
        DateFormat('MMMM yyyy').format(DateTime(data.year, data.month));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (context) => [
          _buildHeader(
            title: 'MONTHLY FINANCIAL SUMMARY',
            subtitle: 'Period: $monthName',
            reportRef: data.reportRef,
            date: data.generatedAt,
          ),

          // KPI Grid
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCol('Expected Dues',
                    '${data.duesExpected.toStringAsFixed(0)} ETB'),
                _buildMetricCol('Collected Dues',
                    '${data.duesCollected.toStringAsFixed(0)} ETB',
                    color: primaryColor),
                _buildMetricCol('Collection Rate',
                    '${data.collectionRate.toStringAsFixed(1)}%',
                    color: accentColor),
                _buildMetricCol('Claims Disbursed',
                    '${data.totalClaimsDisbursed.toStringAsFixed(0)} ETB',
                    color: dangerColor),
                _buildMetricCol('Net Addition',
                    '${data.netChangeInFund.toStringAsFixed(0)} ETB',
                    color: data.netChangeInFund >= 0
                        ? successColor
                        : dangerColor),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Member Collection Stats
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: const pw.BoxDecoration(color: lightBg),
                  child: pw.Text(
                    'Active Members: ${data.totalActiveMembers}   |   Paid: ${data.membersPaid}   |   Unpaid / Arrears: ${data.membersInArrears}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // Transactions Table
          pw.Text('Contribution Receipts for Period',
              style: const pw.TextStyle(
                  fontSize: 12, color: primaryColor)),
          pw.SizedBox(height: 6),

          pw.TableHelper.fromTextArray(
            headers: [
              'Receipt #',
              'Member ID',
              'Member Name',
              'Date',
              'Method',
              'Amount (ETB)'
            ],
            data: data.transactions.isEmpty
                ? [
                    [
                      '-',
                      '-',
                      'No contributions recorded in this period',
                      '-',
                      '-',
                      '0.00 ETB'
                    ]
                  ]
                : data.transactions.map((t) {
                    final statusPrefix = t.isReversed
                        ? '[REV] '
                        : (t.isReversal ? '[OFFSET] ' : '');
                    return [
                      '$statusPrefix${t.receiptNumber}',
                      t.memberId,
                      t.memberName,
                      dfDate.format(t.date),
                      t.paymentMethod.name.toUpperCase(),
                      '${t.amount.toStringAsFixed(0)} ETB',
                    ];
                  }).toList(),
            headerStyle: const pw.TextStyle(
                fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primaryColor),
            rowDecoration: const pw.BoxDecoration(color: lightBg),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {5: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 16),

          _buildSignatures(),
        ],
      ),
    );

    return pdf.save();
  }

  // ── 2. Annual Balance Sheet PDF ────────────────────────────────────────────
  Future<Uint8List> generateAnnualReportPdf(AnnualReportData data) async {
    final pdf = pw.Document();
    final theme = await _loadTheme();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (context) => [
          _buildHeader(
            title: 'ANNUAL BALANCE SHEET & FINANCIAL REPORT',
            subtitle: 'Fiscal Year: ${data.year}',
            reportRef: data.reportRef,
            date: data.generatedAt,
          ),

          // Institutional Summary Box
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricCol('Gross Contributions',
                        '${data.grossContributions.toStringAsFixed(0)} ETB',
                        color: primaryColor),
                    _buildMetricCol('Claims Disbursed',
                        '${data.claimsDisbursed.toStringAsFixed(0)} ETB',
                        color: dangerColor),
                    _buildMetricCol('Operating Expenses',
                        '${data.operationalExpenses.toStringAsFixed(0)} ETB',
                        color: mutedText),
                    _buildMetricCol('Net Operating Surplus',
                        '${data.netSurplus.toStringAsFixed(0)} ETB',
                        color: data.netSurplus >= 0
                            ? successColor
                            : dangerColor),
                  ],
                ),
                pw.Divider(color: borderColor, height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Reserve Fund Balance (Rule 3 Equation):',
                        style: const pw.TextStyle(
                            fontSize: 11)),
                    pw.Text('${data.closingReserveFund.toStringAsFixed(0)} ETB',
                        style: const pw.TextStyle(
                            fontSize: 13,
                            color: primaryColor)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Monthly Breakdown Table
          pw.Text('12-Month Fiscal Breakdown',
              style: const pw.TextStyle(
                  fontSize: 12, color: primaryColor)),
          pw.SizedBox(height: 6),

          pw.TableHelper.fromTextArray(
            headers: [
              'Month',
              'Dues Collected',
              'Expenses / Payouts',
              'Net Surplus / Deficit'
            ],
            data: data.monthlyBreakdown.map((b) {
              final monthName =
                  DateFormat('MMMM').format(DateTime(data.year, b.month));
              return [
                monthName,
                '${b.collected.toStringAsFixed(0)} ETB',
                '${b.expenses.toStringAsFixed(0)} ETB',
                '${b.net.toStringAsFixed(0)} ETB',
              ];
            }).toList(),
            headerStyle: const pw.TextStyle(
                fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primaryColor),
            rowDecoration: const pw.BoxDecoration(color: lightBg),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 16),

          _buildSignatures(),
        ],
      ),
    );

    return pdf.save();
  }

  // ── 3. Arrears Report PDF ──────────────────────────────────────────────────
  Future<Uint8List> generateArrearsReportPdf(ArrearsReportData data) async {
    final pdf = pw.Document();
    final theme = await _loadTheme();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (context) => [
          _buildHeader(
            title: 'ARREARS & DEFAULTING MEMBERS REGISTER',
            subtitle: 'Institutional Compliance and Overdue Dues Audit',
            reportRef: data.reportRef,
            date: data.generatedAt,
          ),

          // Summary Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'Total Defaulting Members: ${data.totalDefaultingMembers}',
                    style: const pw.TextStyle(
                        fontSize: 11,
                        color: dangerColor)),
                pw.Text(
                    'Total Outstanding Debt: ${data.totalArrearsAmount.toStringAsFixed(0)} ETB',
                    style: const pw.TextStyle(
                        fontSize: 11,
                        color: dangerColor)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          pw.TableHelper.fromTextArray(
            headers: [
              'Member ID',
              'Full Name',
              'Phone Number',
              'Monthly Rate',
              'Months Overdue',
              'Total Owed (ETB)'
            ],
            data: data.items.isEmpty
                ? [
                    [
                      '-',
                      'All members are up to date! No arrears recorded.',
                      '-',
                      '-',
                      '-',
                      '0.00 ETB'
                    ]
                  ]
                : data.items.map((item) {
                    return [
                      item.memberId,
                      item.fullName,
                      item.phone,
                      '${item.monthlyDues.toStringAsFixed(0)} ETB',
                      '${item.monthsOverdue} mo',
                      '${item.totalOwed.toStringAsFixed(0)} ETB',
                    ];
                  }).toList(),
            headerStyle: const pw.TextStyle(
                fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primaryColor),
            rowDecoration: const pw.BoxDecoration(color: lightBg),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 16),

          _buildSignatures(),
        ],
      ),
    );

    return pdf.save();
  }

  // ── 4. Member Statement PDF ────────────────────────────────────────────────
  Future<Uint8List> generateMemberStatementPdf(MemberStatementData data) async {
    final pdf = pw.Document();
    final theme = await _loadTheme();
    final df = DateFormat('dd MMM yyyy');

    final standingLabel = switch (data.standing) {
      MemberStanding.inArrears =>
        'IN ARREARS (${data.monthsOverdue} months)',
      MemberStanding.prepaid =>
        'PREPAID (+${data.balanceOrArrears.toStringAsFixed(0)} ETB)',
      MemberStanding.upToDate => 'IN GOOD STANDING',
    };

    final standingColor = switch (data.standing) {
      MemberStanding.inArrears => dangerColor,
      MemberStanding.prepaid => primaryColor,
      MemberStanding.upToDate => successColor,
    };

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (context) => [
          _buildHeader(
            title: 'MEMBER DUES STATEMENT',
            subtitle: 'Official Individual Contribution Ledger Record',
            reportRef: data.reportRef,
            date: data.generatedAt,
          ),

          // Member Profile Box
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Member: ${data.member.fullName}',
                            style: const pw.TextStyle(
                                fontSize: 12)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                            'Member ID: ${data.member.memberId}   |   Phone: ${data.member.phone}',
                            style: const pw.TextStyle(
                                fontSize: 9, color: mutedText)),
                        pw.Text(
                            'Registered: ${df.format(data.member.registeredAt)}',
                            style: const pw.TextStyle(
                                fontSize: 9, color: mutedText)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: standingColor,
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            standingLabel,
                            style: const pw.TextStyle(
                                fontSize: 8, color: PdfColors.white),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                            'Monthly Dues: ${data.member.monthlyDues.toStringAsFixed(0)} ETB',
                            style: const pw.TextStyle(
                                fontSize: 9)),
                        pw.Text(
                            'Total Paid: ${data.totalPaid.toStringAsFixed(0)} ETB',
                            style: const pw.TextStyle(
                                fontSize: 9, color: mutedText)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          pw.Text('Contribution Payment History',
              style: const pw.TextStyle(
                  fontSize: 12, color: primaryColor)),
          pw.SizedBox(height: 6),

          pw.TableHelper.fromTextArray(
            headers: [
              'Receipt #',
              'Date',
              'Period',
              'Method',
              'Recorded By',
              'Amount (ETB)'
            ],
            data: data.contributionsHistory.isEmpty
                ? [
                    [
                      '-',
                      '-',
                      'No payment records yet',
                      '-',
                      '-',
                      '0.00 ETB'
                    ]
                  ]
                : data.contributionsHistory.map((c) {
                    final statusPrefix = c.isReversed
                        ? '[REV] '
                        : (c.isReversal ? '[OFFSET] ' : '');
                    return [
                      '$statusPrefix${c.receiptNumber}',
                      df.format(c.date),
                      '${c.periodMonth}/${c.periodYear}',
                      c.paymentMethod.name.toUpperCase(),
                      c.recordedByName,
                      '${c.amount.toStringAsFixed(0)} ETB',
                    ];
                  }).toList(),
            headerStyle: const pw.TextStyle(
                fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primaryColor),
            rowDecoration: const pw.BoxDecoration(color: lightBg),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {5: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 16),

          _buildSignatures(),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildMetricCol(String label, String value, {PdfColor? color}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: mutedText)),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            color: color ?? darkText,
          ),
        ),
      ],
    );
  }
}
