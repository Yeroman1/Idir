import { Prisma } from '@prisma/client';
import { prisma } from '../../config/database.js';
import { NotFoundError, BadRequestError } from '../../shared/errors/AppError.js';
import { RecordExpenseInput, ReviewExpenseInput } from './expenses.validation.js';

export class ExpensesService {
  async recordExpense(idirId: string, input: RecordExpenseInput, actorId: string) {
    const expenseDate = input.expenseDate ? new Date(input.expenseDate) : new Date();

    const expense = await prisma.expense.create({
      data: {
        idirId,
        category: input.category || 'OTHER',
        amount: new Prisma.Decimal(input.amount),
        currency: 'ETB',
        expenseDate,
        description: input.description,
        receiptUrl: input.receiptUrl,
        status: 'PENDING',
        recordedById: actorId,
      },
      include: {
        recordedBy: {
          select: { id: true, fullName: true },
        },
      },
    });

    await prisma.auditLog.create({
      data: {
        actorId,
        idirId,
        action: 'RECORD_EXPENSE',
        entityType: 'Expense',
        entityId: expense.id,
        safeMetadata: {
          amount: input.amount,
          category: input.category,
          description: input.description,
        },
      },
    });

    return expense;
  }

  async reviewExpense(
    idirId: string,
    expenseId: string,
    input: ReviewExpenseInput,
    actorId: string
  ) {
    const expense = await prisma.expense.findFirst({
      where: { id: expenseId, idirId },
    });

    if (!expense) {
      throw new NotFoundError('Expense record not found');
    }

    if (expense.status !== 'PENDING') {
      throw new BadRequestError(`Cannot review expense that is already ${expense.status}`);
    }

    const newStatus = input.approved ? 'APPROVED' : 'REJECTED';

    return prisma.$transaction(async (tx) => {
      const updated = await tx.expense.update({
        where: { id: expenseId },
        data: {
          status: newStatus,
          approvedById: input.approved ? actorId : null,
          approvedAt: input.approved ? new Date() : null,
          rejectionReason: !input.approved ? input.rejectionReason : null,
        },
        include: {
          recordedBy: { select: { id: true, fullName: true } },
          approvedBy: { select: { id: true, fullName: true } },
        },
      });

      await tx.auditLog.create({
        data: {
          actorId,
          idirId,
          action: input.approved ? 'APPROVE_EXPENSE' : 'REJECT_EXPENSE',
          entityType: 'Expense',
          entityId: expenseId,
          safeMetadata: {
            status: newStatus,
            amount: expense.amount.toString(),
            rejectionReason: input.rejectionReason,
          },
        },
      });

      return updated;
    });
  }

  async listExpenses(
    idirId: string,
    params: {
      page?: number;
      limit?: number;
      category?: RecordExpenseInput['category'];
      status?: 'PENDING' | 'APPROVED' | 'REJECTED' | 'PAID';
      startDate?: string;
      endDate?: string;
    }
  ) {
    const page = Number(params.page) || 1;
    const limit = Number(params.limit) || 20;
    const skip = (page - 1) * limit;

    const where: Prisma.ExpenseWhereInput = {
      idirId,
      ...(params.category && { category: params.category }),
      ...(params.status && { status: params.status }),
      ...(params.startDate || params.endDate
        ? {
            expenseDate: {
              ...(params.startDate && { gte: new Date(params.startDate) }),
              ...(params.endDate && { lte: new Date(params.endDate) }),
            },
          }
        : {}),
    };

    const [total, expenses] = await Promise.all([
      prisma.expense.count({ where }),
      prisma.expense.findMany({
        where,
        skip,
        take: limit,
        orderBy: { expenseDate: 'desc' },
        include: {
          recordedBy: { select: { id: true, fullName: true } },
          approvedBy: { select: { id: true, fullName: true } },
        },
      }),
    ]);

    return {
      items: expenses,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getExpenseById(idirId: string, expenseId: string) {
    const expense = await prisma.expense.findFirst({
      where: { id: expenseId, idirId },
      include: {
        recordedBy: { select: { id: true, fullName: true } },
        approvedBy: { select: { id: true, fullName: true } },
      },
    });

    if (!expense) {
      throw new NotFoundError('Expense not found');
    }

    return expense;
  }
}

export const expensesService = new ExpensesService();
