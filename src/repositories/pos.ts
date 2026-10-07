// Counter sales: cash shifts, invoices and payments. Every write is an RPC that prices the sale
// in the database (create_invoice), so nothing the client sends decides an amount.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { filterSafe, pageRange, unwrap, type Page, type PageParams } from "./shared";

type Client = SupabaseClient<Database>;

export type LineType = "product" | "service" | "combo";
export type PaymentMethod = "cash" | "transfer" | "card";
export type InvoiceStatus = "paid" | "cancelled";
export type ShiftStatus = "open" | "closed";

export const PAYMENT_METHODS: readonly PaymentMethod[] = ["cash", "transfer", "card"];

/** A discount above this share of the subtotal needs "pos: UPDATE" (checked again in the database). */
export const DISCOUNT_LIMIT = 0.1;

// ------------------------------------------------------------------ shifts
export type CashShift = {
  id: string;
  code: string;
  branchId: string;
  status: ShiftStatus;
  openedBy: string;
  openedByName: string | null;
  openedAt: string;
  openingCash: number;
  closedByName: string | null;
  closedAt: string | null;
  expectedCash: number | null;
  countedCash: number | null;
  closeNote: string | null;
};

export type ShiftSummary = {
  openingCash: number;
  invoiceCount: number;
  cancelledCount: number;
  salesTotal: number;
  discountTotal: number;
  changeTotal: number;
  cashIn: number;
  transferIn: number;
  cardIn: number;
  expectedCash: number;
};

export const toCashShift = (row: Tables<"cash_shifts">): CashShift => ({
  id: row.id,
  code: row.code,
  branchId: row.branch_id,
  status: row.status === "closed" ? "closed" : "open",
  openedBy: row.opened_by,
  openedByName: row.opened_by_name,
  openedAt: row.opened_at,
  openingCash: row.opening_cash,
  closedByName: row.closed_by_name,
  closedAt: row.closed_at,
  expectedCash: row.expected_cash,
  countedCash: row.counted_cash,
  closeNote: row.close_note,
});

const num = (value: unknown): number => Number(value ?? 0);

const toShiftSummary = (raw: unknown): ShiftSummary => {
  const row = (raw ?? {}) as Record<string, unknown>;
  return {
    openingCash: num(row.opening_cash),
    invoiceCount: num(row.invoice_count),
    cancelledCount: num(row.cancelled_count),
    salesTotal: num(row.sales_total),
    discountTotal: num(row.discount_total),
    changeTotal: num(row.change_total),
    cashIn: num(row.cash_in),
    transferIn: num(row.transfer_in),
    cardIn: num(row.card_in),
    expectedCash: num(row.expected_cash),
  };
};

/** The caller's open shift at a branch, if any. */
export const getMyOpenShift = async (
  client: Client,
  branchId: string,
  userId: string
): Promise<CashShift | null> => {
  const row = unwrap(
    await client
      .from("cash_shifts")
      .select("*")
      .eq("branch_id", branchId)
      .eq("opened_by", userId)
      .eq("status", "open")
      .maybeSingle()
  );
  return row ? toCashShift(row) : null;
};

export const listShifts = async (
  client: Client,
  branchId: string,
  page: PageParams
): Promise<Page<CashShift>> => {
  const { from, to } = pageRange(page);
  const { data, count, error } = await client
    .from("cash_shifts")
    .select("*", { count: "exact" })
    .eq("branch_id", branchId)
    .order("opened_at", { ascending: false })
    .range(from, to);
  if (error) throw error;
  return { rows: (data ?? []).map(toCashShift), total: count ?? 0 };
};

export const getShiftSummary = async (client: Client, shiftId: string): Promise<ShiftSummary> =>
  toShiftSummary(unwrap(await client.rpc("cash_shift_summary", { p_shift: shiftId })));

export const openShift = async (
  client: Client,
  branchId: string,
  openingCash: number,
  note?: string
): Promise<string> =>
  unwrap(
    await client.rpc("open_cash_shift", {
      p_branch: branchId,
      p_opening_cash: openingCash,
      p_note: note || undefined,
    })
  );

export const closeShift = async (
  client: Client,
  shiftId: string,
  countedCash: number,
  note?: string
): Promise<ShiftSummary> =>
  toShiftSummary(
    unwrap(
      await client.rpc("close_cash_shift", {
        p_shift: shiftId,
        p_counted_cash: countedCash,
        p_note: note || undefined,
      })
    )
  );

// ---------------------------------------------------------------- invoices
export type InvoiceLine = {
  id: string;
  lineNo: number;
  itemType: LineType;
  name: string;
  unit: string | null;
  petName: string | null;
  qty: number;
  unitPrice: number;
  amount: number;
  weightKg: number | null;
};

export type Payment = { id: string; method: PaymentMethod; amount: number; bankRef: string | null };

export type Invoice = {
  id: string;
  code: string;
  branchId: string;
  shiftId: string;
  status: InvoiceStatus;
  customerId: string | null;
  customerName: string | null;
  customerPhone: string | null;
  cashierName: string | null;
  subtotal: number;
  discountAmount: number;
  total: number;
  paidAmount: number;
  changeAmount: number;
  note: string | null;
  createdAt: string;
  cancelledAt: string | null;
  cancelReason: string | null;
};

export type InvoiceDetail = Invoice & { lines: InvoiceLine[]; payments: Payment[] };

const LINE_TYPES: readonly LineType[] = ["product", "service", "combo"];
const toLineType = (value: string): LineType => LINE_TYPES.find((type) => type === value) ?? "product";
const toMethod = (value: string): PaymentMethod => PAYMENT_METHODS.find((method) => method === value) ?? "cash";

export const toInvoice = (row: Tables<"invoices">): Invoice => ({
  id: row.id,
  code: row.code,
  branchId: row.branch_id,
  shiftId: row.shift_id,
  status: row.status === "cancelled" ? "cancelled" : "paid",
  customerId: row.customer_id,
  customerName: row.customer_name,
  customerPhone: row.customer_phone,
  cashierName: row.cashier_name,
  subtotal: row.subtotal,
  discountAmount: row.discount_amount,
  total: row.total,
  paidAmount: row.paid_amount,
  changeAmount: row.change_amount,
  note: row.note,
  createdAt: row.created_at,
  cancelledAt: row.cancelled_at,
  cancelReason: row.cancel_reason,
});

const toInvoiceLine = (row: Tables<"invoice_lines">): InvoiceLine => ({
  id: row.id,
  lineNo: row.line_no,
  itemType: toLineType(row.item_type),
  name: row.name,
  unit: row.unit,
  petName: row.pet_name,
  qty: row.qty,
  unitPrice: row.unit_price,
  amount: row.amount,
  weightKg: row.weight_kg,
});

export type InvoiceFilter = {
  branchId: string;
  /** Inclusive ISO bounds on created_at. */
  from?: string;
  to?: string;
  status?: InvoiceStatus;
  shiftId?: string;
  /** Invoice code, customer name or phone. */
  search?: string;
};

export const listInvoices = async (
  client: Client,
  page: PageParams,
  filter: InvoiceFilter
): Promise<Page<Invoice>> => {
  const { from, to } = pageRange(page);
  let query = client
    .from("invoices")
    .select("*", { count: "exact" })
    .eq("branch_id", filter.branchId)
    .order("created_at", { ascending: false })
    .range(from, to);
  if (filter.from) query = query.gte("created_at", filter.from);
  if (filter.to) query = query.lte("created_at", filter.to);
  if (filter.status) query = query.eq("status", filter.status);
  if (filter.shiftId) query = query.eq("shift_id", filter.shiftId);
  const term = filterSafe(filter.search ?? "");
  if (term) {
    query = query.or(
      [`code.ilike.%${term}%`, `customer_name.ilike.%${term}%`, `customer_phone.ilike.%${term}%`].join(",")
    );
  }

  const { data, count, error } = await query;
  if (error) throw error;
  return { rows: (data ?? []).map(toInvoice), total: count ?? 0 };
};

type InvoiceWithChildren = Tables<"invoices"> & {
  invoice_lines: Tables<"invoice_lines">[];
  payments: Tables<"payments">[];
};

export const getInvoice = async (client: Client, id: string): Promise<InvoiceDetail | null> => {
  const row = unwrap(
    await client.from("invoices").select("*, invoice_lines(*), payments(*)").eq("id", id).maybeSingle()
  ) as InvoiceWithChildren | null;
  if (!row) return null;
  return {
    ...toInvoice(row),
    lines: [...row.invoice_lines].sort((a, b) => a.line_no - b.line_no).map(toInvoiceLine),
    payments: row.payments.map((payment) => ({
      id: payment.id,
      method: toMethod(payment.method),
      amount: payment.amount,
      bankRef: payment.bank_ref,
    })),
  };
};

/** The buyer: an existing customer, a web account, a new walk-in, or nobody. */
export type SaleCustomer =
  | { id: string }
  | { userId: string }
  | { fullName: string; phone: string; email?: string | null }
  | null;

export type SaleLineInput = {
  type: LineType;
  id: string;
  qty: number;
  petId?: string | null;
  weightKg?: number | null;
};

export type SaleInput = {
  branchId: string;
  customer: SaleCustomer;
  lines: SaleLineInput[];
  discountAmount: number;
  payments: { method: PaymentMethod; amount: number; bankRef?: string | null }[];
  note?: string | null;
};

export type SaleResult = { id: string; code: string; total: number; changeAmount: number };

const toCustomerPayload = (customer: SaleCustomer) => {
  if (!customer) return null;
  if ("id" in customer) return { id: customer.id };
  if ("userId" in customer) return { user_id: customer.userId };
  return { full_name: customer.fullName, phone: customer.phone, email: customer.email ?? null };
};

export const createInvoice = async (client: Client, input: SaleInput): Promise<SaleResult> => {
  const raw = unwrap(
    await client.rpc("create_invoice", {
      p: {
        branch_id: input.branchId,
        customer: toCustomerPayload(input.customer),
        discount_amount: input.discountAmount,
        note: input.note ?? null,
        lines: input.lines.map((line) => ({
          type: line.type,
          id: line.id,
          qty: line.qty,
          pet_id: line.petId ?? null,
          weight_kg: line.weightKg ?? null,
        })),
        payments: input.payments.map((payment) => ({
          method: payment.method,
          amount: payment.amount,
          bank_ref: payment.bankRef ?? null,
        })),
      },
    })
  ) as Record<string, unknown>;
  return {
    id: String(raw.id),
    code: String(raw.code),
    total: num(raw.total),
    changeAmount: num(raw.change_amount),
  };
};

export const cancelInvoice = async (client: Client, id: string, reason: string): Promise<void> => {
  const { error } = await client.rpc("cancel_invoice", { p_id: id, p_reason: reason });
  if (error) throw error;
};

// ------------------------------------------------------------ cart helpers
/** A customer's current pets, with species and latest weight for by-weight prices. */
export type CustomerPet = {
  id: string;
  name: string;
  speciesId: string;
  speciesName: string;
  weightKg: number | null;
};

export const listCustomerPets = async (client: Client, customerId: string): Promise<CustomerPet[]> => {
  const links = unwrap(
    await client.from("pet_owners").select("pet_id").eq("customer_id", customerId).is("to_date", null)
  );
  const ids = links.map((link) => link.pet_id);
  if (ids.length === 0) return [];
  const rows = unwrap(
    await client.from("pet_overview").select("*").in("id", ids).eq("status", "active").order("name")
  );
  return rows.map((row) => ({
    id: row.id ?? "",
    name: row.name ?? "",
    speciesId: row.species_id ?? "",
    speciesName: row.species_name ?? "",
    weightKg: row.weight_kg,
  }));
};

/** Price preview for a by-weight service; the sale itself is priced again by create_invoice. */
export const previewServicePrice = async (
  client: Client,
  args: { speciesId: string; serviceId: string; weightKg: number; branchId: string }
): Promise<number | null> => {
  const { data, error } = await client.rpc("get_service_price", {
    p_species_id: args.speciesId,
    p_service_id: args.serviceId,
    p_weight_kg: args.weightKg,
    p_branch_id: args.branchId,
  });
  if (error) throw error;
  return data ?? null;
};

/** Error hints raised by the POS functions, for readable messages. */
export const POS_ERROR_HINTS = [
  "no_open_shift",
  "discount_limit",
  "underpaid",
  "overpaid",
  "shift_closed",
] as const;
export type PosErrorHint = (typeof POS_ERROR_HINTS)[number];

export const posErrorHint = (error: unknown): PosErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return POS_ERROR_HINTS.find((item) => item === hint) ?? null;
};

/** Combos that can be sold now: active, shown (status 1) and priced. Combos sell at their fixed price. */
export type SellableCombo = { id: string; name: string; price: number; speciesIds: string[] };

export const listSellableCombos = async (client: Client): Promise<SellableCombo[]> => {
  const rows = unwrap(
    await client
      .from("pet_service_combos")
      .select("id, name, price, combo_species(species_id)")
      .eq("is_active", true)
      .eq("status", 1)
      .not("price", "is", null)
      .order("name")
  ) as { id: string; name: string; price: number | null; combo_species: { species_id: string }[] }[];
  return rows.map((row) => ({
    id: row.id,
    name: row.name,
    price: row.price ?? 0,
    speciesIds: row.combo_species.map((link) => link.species_id),
  }));
};
