import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { unwrap } from "../shared";
import { num } from "./helpers";

type Client = SupabaseClient<Database>;

// ------------------------------------------------------------------ returns
export type RefundMethod = "cash" | "transfer";
export const REFUND_METHODS: readonly RefundMethod[] = ["cash", "transfer"];

export type SalesReturn = {
  id: string;
  code: string;
  createdAt: string;
  createdByName: string | null;
  refundMethod: RefundMethod;
  refundAmount: number;
  reason: string;
  lines: { invoiceLineId: string; name: string; qty: number; amount: number }[];
};

type ReturnRow = Tables<"sales_returns"> & { sales_return_lines: Tables<"sales_return_lines">[] };

/** Returns taken on an invoice, oldest first. */
export const listInvoiceReturns = async (client: Client, invoiceId: string): Promise<SalesReturn[]> => {
  const rows = unwrap(
    await client
      .from("sales_returns")
      .select("*, sales_return_lines(*)")
      .eq("invoice_id", invoiceId)
      .order("created_at")
  ) as unknown as ReturnRow[];
  return rows.map((row) => ({
    id: row.id,
    code: row.code,
    createdAt: row.created_at,
    createdByName: row.created_by_name,
    refundMethod: row.refund_method === "transfer" ? "transfer" : "cash",
    refundAmount: num(row.refund_amount),
    reason: row.reason,
    lines: row.sales_return_lines.map((line) => ({
      invoiceLineId: line.invoice_line_id,
      name: line.name,
      qty: num(line.qty),
      amount: num(line.amount),
    })),
  }));
};

export type SalesReturnInput = {
  invoiceId: string;
  reason: string;
  refundMethod: RefundMethod;
  lines: { invoiceLineId: string; qty: number }[];
};

/** Takes goods back and refunds them from the caller's open shift; the goods go back to their lots. */
export const createSalesReturn = async (
  client: Client,
  input: SalesReturnInput
): Promise<{ id: string; code: string; refundAmount: number }> => {
  const raw = unwrap(
    await client.rpc("create_sales_return", {
      p: {
        invoice_id: input.invoiceId,
        reason: input.reason,
        refund_method: input.refundMethod,
        lines: input.lines.map((line) => ({ invoice_line_id: line.invoiceLineId, qty: line.qty })),
      },
    })
  ) as Record<string, unknown>;
  return { id: String(raw.id), code: String(raw.code), refundAmount: num(raw.refund_amount) };
};
