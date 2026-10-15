import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { filterSafe, pageRange, unwrap, type Page, type PageParams } from "../shared";
import { num } from "./helpers";
import {
  PAYMENT_METHODS,
  type InvoiceChannel,
  type InvoiceStatus,
  type LineType,
  type PaymentMethod,
} from "./types";

type Client = SupabaseClient<Database>;

// ---------------------------------------------------------------- invoices
export type InvoiceLine = {
  id: string;
  lineNo: number;
  itemType: LineType | "boarding";
  productId: string | null;
  name: string;
  unit: string | null;
  petName: string | null;
  qty: number;
  unitPrice: number;
  amount: number;
  weightKg: number | null;
};

/** "cod" is cash collected by the courier; it is never entered at the counter. */
export type Payment = { id: string; method: PaymentMethod | "cod"; amount: number; bankRef: string | null };

export type Invoice = {
  id: string;
  code: string;
  branchId: string;
  /** Null for an online invoice that was not paid at the counter. */
  shiftId: string | null;
  channel: InvoiceChannel;
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
const toLineType = (value: string): LineType | "boarding" =>
  value === "boarding" ? "boarding" : (LINE_TYPES.find((type) => type === value) ?? "product");
const toMethod = (value: string): PaymentMethod | "cod" =>
  value === "cod" ? "cod" : (PAYMENT_METHODS.find((method) => method === value) ?? "cash");

export const toInvoice = (row: Tables<"invoices">): Invoice => ({
  id: row.id,
  code: row.code,
  branchId: row.branch_id,
  shiftId: row.shift_id,
  channel: row.channel === "online" ? "online" : "pos",
  status: row.status === "cancelled" ? "cancelled" : row.status === "unpaid" ? "unpaid" : "paid",
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
  productId: row.product_id,
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
  /** "appointment_item": a finished spa ticket, `id` is the ticket id. "boarding_charge": a charge of a checked-out stay. "medical_item": a line of a signed visit. */
  type: LineType | "appointment_item" | "boarding_charge" | "medical_item";
  id: string;
  qty: number;
  /** A product's conversion unit; qty then counts that unit. Missing: the base unit. */
  unitId?: string | null;
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
  /** Same for every attempt at one sale, so a retry after a lost response returns the first invoice. */
  clientRef?: string | null;
};

/** `replayed`: the sale had already gone through and this is the invoice made then. */
export type SaleResult = { id: string; code: string; total: number; changeAmount: number; replayed: boolean };

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
        client_ref: input.clientRef ?? null,
        lines: input.lines.map((line) => ({
          type: line.type,
          id: line.id,
          qty: line.qty,
          unit_id: line.unitId ?? null,
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
    replayed: raw.replayed === true,
  };
};

export const cancelInvoice = async (client: Client, id: string, reason: string): Promise<void> => {
  const { error } = await client.rpc("cancel_invoice", { p_id: id, p_reason: reason });
  if (error) throw error;
};
