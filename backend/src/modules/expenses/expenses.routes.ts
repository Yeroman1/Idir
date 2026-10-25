import { Router } from 'express';
import { expensesController } from './expenses.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import {
  recordExpenseSchema,
  reviewExpenseSchema,
  queryExpensesSchema,
} from './expenses.validation.js';
import { requireActiveIdir } from '../../middleware/assertIdirActive.js';

const router = Router({ mergeParams: true });

router.use(authenticate);
router.use(requireActiveIdir());

router.post(
  '/',
  requireIdirRole(['CHAIRPERSON', 'TREASURER', 'SECRETARY']),
  validate({ body: recordExpenseSchema }),
  expensesController.recordExpense
);

router.get(
  '/',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
  ]),
  validate({ query: queryExpensesSchema }),
  expensesController.listExpenses
);

router.get(
  '/:expenseId',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
  ]),
  expensesController.getExpenseById
);

router.post(
  '/:expenseId/review',
  requireIdirRole(['CHAIRPERSON']),
  validate({ body: reviewExpenseSchema }),
  expensesController.reviewExpense
);

export const expenseRoutes = router;
