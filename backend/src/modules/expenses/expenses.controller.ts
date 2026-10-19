import { Response, NextFunction } from 'express';
import { expensesService } from './expenses.service.js';
import { sendSuccess, sendCreated } from '../../shared/utils/response.js';
import { AuthenticatedRequest } from '../../shared/types/index.js';

export class ExpensesController {
  async recordExpense(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const expense = await expensesService.recordExpense(
        req.params.idirId,
        req.body,
        req.user!.id
      );
      return sendCreated(res, expense, 'Expense recorded and submitted for approval');
    } catch (error) {
      next(error);
    }
  }

  async reviewExpense(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const expense = await expensesService.reviewExpense(
        req.params.idirId,
        req.params.expenseId,
        req.body,
        req.user!.id
      );
      return sendSuccess(res, expense, 200, `Expense ${expense.status.toLowerCase()}`);
    } catch (error) {
      next(error);
    }
  }

  async listExpenses(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { page, limit, category, status, startDate, endDate } = req.query;
      const result = await expensesService.listExpenses(req.params.idirId, {
        page: page ? Number(page) : undefined,
        limit: limit ? Number(limit) : undefined,
        category: category as any,
        status: status as any,
        startDate: startDate as string,
        endDate: endDate as string,
      });
      return sendSuccess(res, result.items, 200, undefined, result.meta);
    } catch (error) {
      next(error);
    }
  }

  async getExpenseById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const expense = await expensesService.getExpenseById(
        req.params.idirId,
        req.params.expenseId
      );
      return sendSuccess(res, expense);
    } catch (error) {
      next(error);
    }
  }
}

export const expensesController = new ExpensesController();
