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
        expensesByCategory: expensesByCategory.map((e) => ({
          category: e.category,
          amount: e._sum.amount ? Number(e._sum.amount) : 0,
        })),
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
