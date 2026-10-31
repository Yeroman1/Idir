import { z } from 'zod';

export const recordExpenseSchema = z.object({
  category: z
    .enum([
      'EQUIPMENT',
      'VENUE',
      'EVENT_TENT',
      'UTILITIES',
      'EMERGENCY',
      'FUNERAL_SUPPLIES',
      'ADMINISTRATIVE',
      'OTHER',
    ])
    .default('OTHER'),
  amount: z.coerce.number().positive('Expense amount must be positive'),
  expenseDate: z.string().datetime().or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)).optional(),
  description: z.string().min(3, 'Description must be at least 3 characters'),
  receiptUrl: z.string().optional().nullable(),
});

export const reviewExpenseSchema = z.object({
  approved: z.boolean(),
  rejectionReason: z.string().optional(),
});

export const reverseExpenseSchema = z.object({
  reversalReason: z.string().min(5, 'Reversal reason must be at least 5 characters'),
});

export const queryExpensesSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
  category: z
    .enum([
      'EQUIPMENT',
      'VENUE',
      'EVENT_TENT',
      'UTILITIES',
      'EMERGENCY',
      'FUNERAL_SUPPLIES',
      'ADMINISTRATIVE',
      'OTHER',
    ])
    .optional(),
  status: z.enum(['PENDING', 'APPROVED', 'REJECTED', 'PAID']).optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
});

export type RecordExpenseInput = z.infer<typeof recordExpenseSchema>;
export type ReviewExpenseInput = z.infer<typeof reviewExpenseSchema>;
