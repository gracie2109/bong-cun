// What the POS RPCs return, as the app reads it. packages/supabase parses every result with these
// schemas (parseRpc), and the database tests run the real functions against them, so a renamed key
// in SQL fails in CI instead of showing `undefined` on a screen.
import { z } from "zod";

/** create_invoice */
export const saleResultSchema = z.object({
  id: z.string(),
  code: z.string(),
  total: z.number(),
  change_amount: z.number(),
  replayed: z.boolean().nullish(),
});

/** create_sales_return */
export const salesReturnResultSchema = z.object({ id: z.string(), code: z.string(), refund_amount: z.number() });

/** cash_shift_summary, and the summary inside close_cash_shift */
export const shiftSummarySchema = z.object({
  opening_cash: z.number(),
  invoice_count: z.number(),
  cancelled_count: z.number(),
  sales_total: z.number(),
  discount_total: z.number(),
  change_total: z.number(),
  cash_in: z.number(),
  transfer_in: z.number(),
  card_in: z.number(),
  return_count: z.number(),
  refund_cash: z.number(),
  refund_transfer: z.number(),
  expected_cash: z.number(),
});
