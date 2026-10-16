import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@bongcun/supabase/db";
import { shiftSummarySchema } from "@bongcun/core/pos";
import { pageRange, parseRpc, searchOr, unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { num } from "./helpers";
import type { ShiftStatus } from "./types";

type Client = SupabaseClient<Database>;

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
  /** Returns refunded from this shift (not the shift of the original sale). */
  returnCount: number;
  refundCash: number;
  refundTransfer: number;
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


const toShiftSummary = (raw: unknown): ShiftSummary => {
  const row = parseRpc("cash_shift_summary", shiftSummarySchema, raw);
  return {
    openingCash: row.opening_cash,
    invoiceCount: row.invoice_count,
    cancelledCount: row.cancelled_count,
    salesTotal: row.sales_total,
    discountTotal: row.discount_total,
    changeTotal: row.change_total,
    cashIn: row.cash_in,
    transferIn: row.transfer_in,
    cardIn: row.card_in,
    returnCount: row.return_count,
    refundCash: row.refund_cash,
    refundTransfer: row.refund_transfer,
    expectedCash: row.expected_cash,
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
  page: PageParams,
  filter: { search?: string } = {}
): Promise<Page<CashShift>> => {
  const { from, to } = pageRange(page);
  let query = client
    .from("cash_shifts")
    .select("*", { count: "exact" })
    .eq("branch_id", branchId)
    .order("opened_at", { ascending: false })
    .range(from, to);
  const condition = searchOr(["code", "opened_by_name"], filter.search ?? "");
  if (condition) query = query.or(condition);
  const { data, count, error } = await query;
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
