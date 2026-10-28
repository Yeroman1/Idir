import { prisma } from '../../config/database.js';
import { NotFoundError } from '../../shared/errors/AppError.js';

export class ReportsService {
  async getIdirFinancialReport(
    idirId: string,
    filters?: { startDate?: string; endDate?: string }
  ) {
    const idir = await prisma.idir.findUnique({
      where: { id: idirId },
      select: { id: true, name: true, currency: true },
    });
    if (!idir) {
      throw new NotFoundError('Idir not found');
    }

    const dateFilter =
      filters?.startDate || filters?.endDate
        ? {
            gte: filters.startDate ? new Date(filters.startDate) : undefined,
            lte: filters.endDate ? new Date(filters.endDate) : undefined,
          }
        : undefined;

    // ── 1. IDIR FINANCIALS (MUTUAL AID & OPERATIONS) ──────────────────────────
    const [
      contributionsAgg,
      expensesAgg,
      disbursementsAgg,
      expensesByCategory,
      disbursementsByType,
    ] = await Promise.all([
      // Total confirmed contributions
      prisma.contribution.aggregate({
        where: {
          idirId,
          status: 'CONFIRMED',
          isReversed: false,
          ...(dateFilter && { paymentDate: dateFilter }),
        },
        _sum: { amount: true },
        _count: { id: true },
      }),

      // Total approved or paid expenses
      prisma.expense.aggregate({
        where: {
          idirId,
          status: { in: ['APPROVED', 'PAID'] },
          ...(dateFilter && { expenseDate: dateFilter }),
        },
        _sum: { amount: true },
        _count: { id: true },
      }),

      // Total assistance disbursements
      prisma.assistanceDisbursement.aggregate({
        where: {
          idirId,
          ...(dateFilter && { disbursedAt: dateFilter }),
        },
        _sum: { amount: true },
        _count: { id: true },
      }),

      // Breakdown by expense category
      prisma.expense.groupBy({
        by: ['category'],
        where: {
          idirId,
          status: { in: ['APPROVED', 'PAID'] },
          ...(dateFilter && { expenseDate: dateFilter }),
        },
        _sum: { amount: true },
      }),

      // Breakdown by assistance case type
      prisma.assistanceCase.findMany({
        where: { idirId },
        select: {
          caseType: true,
          requests: {
            select: {
              disbursements: {
                select: { amount: true },
              },
            },
          },
        },
      }),
    ]);

    const idirTotalContributions = contributionsAgg._sum.amount
      ? Number(contributionsAgg._sum.amount)
      : 0;
    const idirTotalExpenses = expensesAgg._sum.amount
      ? Number(expensesAgg._sum.amount)
      : 0;
    const idirTotalDisbursements = disbursementsAgg._sum.amount
      ? Number(disbursementsAgg._sum.amount)
      : 0;

    const idirNetBalance =
      idirTotalContributions - (idirTotalExpenses + idirTotalDisbursements);

    // ── 2. IKUB FINANCIALS (ROTATING SAVINGS — STRICTLY SEPARATED) ───────────
    const [ikubContribAgg, ikubPayoutAgg, ikubGroupsCount] = await Promise.all([
      prisma.ikubContribution.aggregate({
        where: {
          round: { ikubGroup: { idirId } },
          status: 'CONFIRMED',
          ...(dateFilter && { paymentDate: dateFilter }),
        },
        _sum: { amount: true },
        _count: { id: true },
      }),
      prisma.ikubPayout.aggregate({
        where: {
          round: { ikubGroup: { idirId } },
          status: 'CONFIRMED',
          ...(dateFilter && { payoutDate: dateFilter }),
        },
        _sum: { amount: true },
        _count: { id: true },
      }),
      prisma.ikubGroup.count({
        where: { idirId, status: 'ACTIVE' },
      }),
    ]);

    const totalIkubContributions = ikubContribAgg._sum.amount
      ? Number(ikubContribAgg._sum.amount)
      : 0;
    const totalIkubPayouts = ikubPayoutAgg._sum.amount
      ? Number(ikubPayoutAgg._sum.amount)
      : 0;
    const ikubNetPool = totalIkubContributions - totalIkubPayouts;

    // ── 3. OUTSTANDING DUES & RECENT TRANSACTIONS ───────────────────────────
    let totalOutstandingDues = 0;
    try {
      const activeMembers = await prisma.membership.findMany({
        where: { idirId, status: 'ACTIVE' },
        include: {
          contributions: {
            where: { isReversed: false, status: 'CONFIRMED' },
            select: { amount: true },
          },
        },
      });

      const idirSettings = await prisma.idirSettings.findUnique({
        where: { idirId },
      });

      const regularDues = idirSettings?.regularDuesAmount ? Number(idirSettings.regularDuesAmount) : 100;
      const currentMonth = new Date().getMonth() + 1;

      for (const m of (activeMembers || [])) {
        const paid = (m.contributions || []).reduce((sum, c) => sum + Number(c.amount), 0);
        const expected = currentMonth * regularDues;
        if (expected > paid) {
          totalOutstandingDues += (expected - paid);
        }
      }
    } catch {
      totalOutstandingDues = 0;
    }

    let recentTransactions: any[] = [];
    try {
      const [recentContribs, recentExps, recentDisbs] = await Promise.all([
        prisma.contribution.findMany({
          where: { idirId, ...(dateFilter && { paymentDate: dateFilter }) },
          take: 10,
          orderBy: { paymentDate: 'desc' },
          include: {
            membership: { include: { user: { select: { fullName: true } } } },
            contributionType: true,
          },
        }),
        prisma.expense.findMany({
          where: { idirId, ...(dateFilter && { expenseDate: dateFilter }) },
          take: 10,
          orderBy: { expenseDate: 'desc' },
          include: { recordedBy: { select: { fullName: true } } },
        }),
        prisma.assistanceDisbursement.findMany({
          where: { idirId, ...(dateFilter && { disbursedAt: dateFilter }) },
          take: 10,
          orderBy: { disbursedAt: 'desc' },
        }),
      ]);

      const txList: any[] = [];
      for (const c of (recentContribs || [])) {
        txList.push({
          id: c.id,
          type: 'CONTRIBUTION',
          title: `Contribution: ${c.membership?.user?.fullName || 'Member'}`,
          description: c.contributionType?.name || 'Regular Dues',
          amount: Number(c.amount),
          date: c.paymentDate,
          paymentMethod: c.paymentMethod,
          receiptNumber: c.receiptNumber,
          status: c.isReversed ? 'REVERSED' : (c.status === 'CONFIRMED' ? 'VERIFIED' : 'RECORDED'),
        });
      }
      for (const e of (recentExps || [])) {
        txList.push({
          id: e.id,
          type: 'EXPENSE',
          title: `Expense: ${e.category}`,
          description: e.description,
          amount: Number(e.amount),
          date: e.expenseDate,
          receiptUrl: e.receiptUrl,
          status: (e.status === 'APPROVED' || e.status === 'PAID') ? 'VERIFIED' : (e.status === 'REJECTED' ? 'REJECTED' : 'RECORDED'),
        });
      }
      for (const d of (recentDisbs || [])) {
        txList.push({
          id: d.id,
          type: 'ASSISTANCE',
          title: `Assistance: ${d.recipientName}`,
          description: `Disbursement (${d.receiptNumber})`,
          amount: Number(d.amount),
          date: d.disbursedAt,
          paymentMethod: d.paymentMethod,
          receiptNumber: d.receiptNumber,
          status: 'VERIFIED',
        });
      }

      txList.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
      recentTransactions = txList.slice(0, 15);
    } catch {
      recentTransactions = [];
    }

    return {
      idir: {
        id: idir.id,
        name: idir.name,
        currency: idir.currency,
      },
      period: {
        startDate: filters?.startDate || 'All time',
        endDate: filters?.endDate || 'Present',
      },
      // Isolated Idir Accounting
      idirLedger: {
        totalContributions: idirTotalContributions,
        contributionsCount: contributionsAgg._count.id,
        totalExpenses: idirTotalExpenses,
        expensesCount: expensesAgg._count.id,
        totalDisbursements: idirTotalDisbursements,
        disbursementsCount: disbursementsAgg._count.id,
        netBalance: idirNetBalance,
        outstandingContributions: totalOutstandingDues,
        expensesByCategory: expensesByCategory.map((e) => ({
          category: e.category,
          amount: e._sum.amount ? Number(e._sum.amount) : 0,
        })),
        recentTransactions,
      },
      // Completely Segregated Ikub Accounting
      ikubLedger: {
        activeGroupsCount: ikubGroupsCount,
        totalContributions: totalIkubContributions,
        contributionsCount: ikubContribAgg._count.id,
        totalPayouts: totalIkubPayouts,
        payoutsCount: ikubPayoutAgg._count.id,
        netPoolBalance: ikubNetPool,
      },
    };
  }

  async generateFinancialCsv(
    idirId: string,
    filters?: { startDate?: string; endDate?: string }
  ) {
    const report = await this.getIdirFinancialReport(idirId, filters);
    const dateGenerated = new Date().toISOString();
    const periodCovered = `${filters?.startDate || 'All Time'} to ${filters?.endDate || 'Present'}`;

    const lines: string[] = [];
    lines.push(`"IDIR FINANCIAL REPORT - AUDITABLE LEDGER"`);
    lines.push(`"Idir Name","${report.idir.name}"`);
    lines.push(`"Currency","${report.idir.currency}"`);
    lines.push(`"Period Covered","${periodCovered}"`);
    lines.push(`"Date Generated","${dateGenerated}"`);
    lines.push(``);

    lines.push(`"--- EXECUTIVE SUMMARY ---"`);
    lines.push(`"Metric","Value"`);
    lines.push(`"Total Contributions Collected","${report.idirLedger.totalContributions}"`);
    lines.push(`"Total Operational Expenses","${report.idirLedger.totalExpenses}"`);
    lines.push(`"Total Assistance Disbursed","${report.idirLedger.totalDisbursements}"`);
    lines.push(`"Net Idir Fund Balance","${report.idirLedger.netBalance}"`);
    lines.push(`"Outstanding Contributions","${report.idirLedger.outstandingContributions}"`);
    lines.push(`"Total Confirmed Contributions Count","${report.idirLedger.contributionsCount}"`);
    lines.push(`"Total Approved Expenses Count","${report.idirLedger.expensesCount}"`);
    lines.push(`"Total Assistance Disbursements Count","${report.idirLedger.disbursementsCount}"`);
    lines.push(``);

    lines.push(`"--- EXPENSES BY CATEGORY ---"`);
    lines.push(`"Category","Total Amount (${report.idir.currency})"`);
    for (const exp of report.idirLedger.expensesByCategory) {
      lines.push(`"${exp.category}","${exp.amount}"`);
    }
    lines.push(``);

    lines.push(`"--- RECENT TRANSACTIONS ---"`);
    lines.push(`"Type","Title","Description","Amount","Date","Status"`);
    for (const tx of report.idirLedger.recentTransactions) {
      lines.push(`"${tx.type}","${tx.title}","${tx.description}","${tx.amount}","${tx.date}","${tx.status}"`);
    }
    lines.push(``);

    lines.push(`"--- SEGREGATED IKUB POOL SUMMARY ---"`);
    lines.push(`"Active Ikub Groups","${report.ikubLedger.activeGroupsCount}"`);
    lines.push(`"Total Ikub Contributions","${report.ikubLedger.totalContributions}"`);
    lines.push(`"Total Ikub Payouts","${report.ikubLedger.totalPayouts}"`);
    lines.push(`"Net Ikub Pool Balance","${report.ikubLedger.netPoolBalance}"`);

    return {
      filename: `idir_financial_report_${report.idir.id.slice(0, 8)}_${new Date().toISOString().slice(0, 10)}.csv`,
      csv: lines.join('\n'),
      data: report,
    };
  }

  async getMemberContributionReport(idirId: string, membershipId: string) {
    const membership = await prisma.membership.findFirst({
      where: { id: membershipId, idirId },
      include: {
        user: { select: { fullName: true, phoneNumber: true } },
      },
    });
    if (!membership) {
      throw new NotFoundError('Membership record not found');
    }

    const [contributions, totals] = await Promise.all([
      prisma.contribution.findMany({
        where: { membershipId, isReversed: false },
        orderBy: { paymentDate: 'desc' },
        include: { contributionType: true },
      }),
      prisma.contribution.aggregate({
        where: { membershipId, status: 'CONFIRMED', isReversed: false },
        _sum: { amount: true },
      }),
    ]);

    return {
      member: {
        id: membership.id,
        memberNumber: membership.memberNumber,
        fullName: membership.user.fullName,
        phoneNumber: membership.user.phoneNumber,
        role: membership.role,
        joinedAt: membership.joinedAt,
      },
      totalPaid: totals._sum.amount ? Number(totals._sum.amount) : 0,
      contributions,
    };
  }
}

export const reportsService = new ReportsService();
