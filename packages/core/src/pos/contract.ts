// Use-case contracts of the counter money flow (sell, return, shift). Input schemas are camelCase and
// say what a caller sends; result schemas describe the `jsonb` the database function answers with.
// The Supabase adapter maps names; screens never see `snake_case`. A changed database answer fails
// the RPC shape tests (apps/web/tests/db) instead of showing `undefined` on a screen.
import { z } from "zod";

export const PAYMENT_METHODS = ["cash", "transfer", "card"] as const;
export const paymentMethod = z.enum(PAYMENT_METHODS);
export type PaymentMethod = z.infer<typeof paymentMethod>;

const refundMethod = z.enum(["cash", "transfer"]);

const uuid = z.string().uuid();

// ---------------------------------------------------------------- createInvoice
export const SALE_LINE_TYPES = ["product", "service", "combo", "appointment_item", "boarding_charge", "medical_item"] as const;

export const saleLineInput = z.object({
  type: z.enum(SALE_LINE_TYPES),
  id: uuid,
  qty: z.number().positive(),
  unitId: uuid.nullish(),
  petId: uuid.nullish(),
  weightKg: z.number().positive().nullish(),
});

export const saleCustomerInput = z
  .union([
    z.object({ id: uuid }),
    z.object({ userId: uuid }),
    z.object({ fullName: z.string().min(1), phone: z.string().min(1), email: z.string().nullish() }),
  ])
  .nullable();

export const saleInput = z.object({
  branchId: uuid,
  customer: saleCustomerInput,
  lines: z.array(saleLineInput).min(1),
  discountAmount: z.number().min(0),
  payments: z.array(
    z.object({ method: paymentMethod, amount: z.number().positive(), bankRef: z.string().nullish() })
  ),
  note: z.string().nullish(),
  /** Same for every attempt at one sale, so a retry after a lost response returns the first invoice. */
  clientRef: uuid.nullish(),
});
export type SaleInputContract = z.infer<typeof saleInput>;

/** `create_invoice` answers `{ id, code, total, change_amount, replayed }`. */
export const saleResultSchema = z.object({
  id: z.string(),
  code: z.string(),
  total: z.number(),
  change_amount: z.number(),
  replayed: z.boolean().nullish(),
});

// ---------------------------------------------------------------- createSalesReturn
export const salesReturnInput = z.object({
  invoiceId: uuid,
  reason: z.string().min(1),
  refundMethod,
  lines: z.array(z.object({ invoiceLineId: uuid, qty: z.number().positive() })).min(1),
});

/** `create_sales_return` answers `{ id, code, refund_amount }`. */
export const salesReturnResultSchema = z.object({ id: z.string(), code: z.string(), refund_amount: z.number() });

// ---------------------------------------------------------------- cash shifts
export const openShiftInput = z.object({
  branchId: uuid,
  openingCash: z.number().min(0),
  note: z.string().nullish(),
});

export const closeShiftInput = z.object({
  shiftId: uuid,
  countedCash: z.number().min(0),
  note: z.string().nullish(),
});

/** `cash_shift_summary` (and `close_cash_shift`, which adds `counted_cash`). */
export const shiftSummarySchema = z.object({
  shift_id: z.string().optional(),
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
  counted_cash: z.number().optional(),
});
