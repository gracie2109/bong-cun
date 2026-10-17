import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { StockDocumentInput } from "@bongcun/core/inventory";
import { filterSafe, pageRange, unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { toDocument, toDocumentDetail, toLinePayload, type DocumentLineRow, type DocumentRow } from "./mappers";
import type { StockDocument, StockDocumentDetail, StockDocumentFilter } from "./types";

type Client = SupabaseClient<Database>;

export const listStockDocuments = async (
  client: Client,
  page: PageParams,
  filter: StockDocumentFilter
): Promise<Page<StockDocument>> => {
  const { from, to } = pageRange(page);
  let query = client
    .from("stock_documents")
    .select("*, suppliers(name)", { count: "exact" })
    .eq("branch_id", filter.branchId)
    .order("created_at", { ascending: false })
    .range(from, to);
  if (filter.docType) query = query.eq("doc_type", filter.docType);
  if (filter.status) query = query.eq("status", filter.status);
  const term = filterSafe(filter.search ?? "");
  if (term) query = query.or([`code.ilike.%${term}%`, `supplier_ref.ilike.%${term}%`, `note.ilike.%${term}%`].join(","));

  const { data, count, error } = await query;
  if (error) throw error;
  return { rows: ((data ?? []) as unknown as DocumentRow[]).map(toDocument), total: count ?? 0 };
};

export const getStockDocument = async (client: Client, id: string): Promise<StockDocumentDetail | null> => {
  const row = unwrap(
    await client
      .from("stock_documents")
      .select("*, suppliers(name), stock_document_lines(*, products(name, unit, product_units(*)))")
      .eq("id", id)
      .maybeSingle()
  ) as unknown as (DocumentRow & { stock_document_lines: DocumentLineRow[] }) | null;
  return row ? toDocumentDetail(row) : null;
};

/** Creates or replaces a draft; returns its id. */
export const saveStockDocument = async (client: Client, input: StockDocumentInput): Promise<string> => {
  return unwrap(
    await client.rpc("save_stock_document", {
      p: {
        id: input.id ?? null,
        branch_id: input.branchId,
        doc_type: input.docType,
        supplier_id: input.supplierId ?? null,
        supplier_ref: input.supplierRef ?? null,
        note: input.note ?? null,
        lines: input.lines.map(toLinePayload),
      },
    })
  );
};

export const postStockDocument = async (client: Client, id: string): Promise<void> => {
  const { error } = await client.rpc("post_stock_document", { p_id: id });
  if (error) throw error;
};

export const cancelStockDocument = async (client: Client, id: string, reason?: string): Promise<void> => {
  const { error } = await client.rpc("cancel_stock_document", { p_id: id, p_reason: reason || undefined });
  if (error) throw error;
};
