import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { toUnit } from "../products/mappers";
import type { ProductUnit } from "../products/types";
import { filterSafe, pageRange, unwrap, type Page, type PageParams } from "../shared";
import { num } from "./helpers";

type Client = SupabaseClient<Database>;

// ----------------------------------------------------------------- documents
export const DOC_TYPES = ["receipt", "writeoff", "count"] as const;
export type DocType = (typeof DOC_TYPES)[number];
export const DOC_STATUSES = ["draft", "posted", "cancelled"] as const;
export type DocStatus = (typeof DOC_STATUSES)[number];

export type StockDocument = {
  id: string;
  code: string;
  branchId: string;
  docType: DocType;
  status: DocStatus;
  supplierId: string | null;
  supplierName: string | null;
  supplierRef: string | null;
  note: string | null;
  totalCost: number;
  createdAt: string;
  createdByName: string | null;
  postedAt: string | null;
  postedByName: string | null;
  cancelledAt: string | null;
  cancelledByName: string | null;
  cancelReason: string | null;
};

export type StockDocumentLine = {
  id: string;
  lineNo: number;
  productId: string;
  productName: string;
  unit: string;
  lotId: string | null;
  lotNo: string;
  expiryDate: string | null;
  qty: number;
  unitCost: number;
  /** A receipt line keeps what was typed: `enteredQty` of `unitName` at `enteredCost` each. */
  unitId: string | null;
  unitName: string | null;
  unitFactor: number;
  enteredQty: number | null;
  enteredCost: number | null;
  /** The product's conversion units, to pick another unit while the draft is edited. */
  productUnits: ProductUnit[];
  systemQty: number | null;
  countedQty: number | null;
  note: string | null;
};

export type StockDocumentDetail = StockDocument & { lines: StockDocumentLine[] };

type DocumentRow = Tables<"stock_documents"> & { suppliers: { name: string } | null };
type DocumentLineRow = Tables<"stock_document_lines"> & {
  products: { name: string; unit: string; product_units: Tables<"product_units">[] } | null;
};

const toDocType = (value: string): DocType => DOC_TYPES.find((type) => type === value) ?? "receipt";
const toDocStatus = (value: string): DocStatus => DOC_STATUSES.find((status) => status === value) ?? "draft";

const toDocument = (row: DocumentRow): StockDocument => ({
  id: row.id,
  code: row.code,
  branchId: row.branch_id,
  docType: toDocType(row.doc_type),
  status: toDocStatus(row.status),
  supplierId: row.supplier_id,
  supplierName: row.suppliers?.name ?? null,
  supplierRef: row.supplier_ref,
  note: row.note,
  totalCost: num(row.total_cost),
  createdAt: row.created_at,
  createdByName: row.created_by_name,
  postedAt: row.posted_at,
  postedByName: row.posted_by_name,
  cancelledAt: row.cancelled_at,
  cancelledByName: row.cancelled_by_name,
  cancelReason: row.cancel_reason,
});

export type StockDocumentFilter = {
  branchId: string;
  docType?: DocType;
  status?: DocStatus;
  /** Document code, supplier reference or note. */
  search?: string;
};

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
  if (!row) return null;
  return {
    ...toDocument(row),
    lines: [...row.stock_document_lines]
      .sort((a, b) => a.line_no - b.line_no)
      .map((line) => ({
        id: line.id,
        lineNo: line.line_no,
        productId: line.product_id,
        productName: line.products?.name ?? "",
        unit: line.products?.unit ?? "",
        lotId: line.lot_id,
        lotNo: line.lot_no,
        expiryDate: line.expiry_date,
        qty: num(line.qty),
        unitCost: num(line.unit_cost),
        unitId: line.unit_id,
        unitName: line.unit_name,
        unitFactor: num(line.unit_factor),
        enteredQty: line.entered_qty === null ? null : num(line.entered_qty),
        enteredCost: line.entered_cost === null ? null : num(line.entered_cost),
        productUnits: (line.products?.product_units ?? []).map(toUnit),
        systemQty: line.system_qty === null ? null : num(line.system_qty),
        countedQty: line.counted_qty === null ? null : num(line.counted_qty),
        note: line.note,
      })),
  };
};

/** Receipt lines name a lot; write-off and count lines point at an existing one. */
export type StockDocumentLineInput =
  | {
      productId: string;
      /** The conversion unit qty and unitCost are in; missing: the base unit. */
      unitId?: string | null;
      lotNo: string;
      expiryDate: string | null;
      qty: number;
      unitCost: number;
      note?: string | null;
    }
  | { lotId: string; qty: number; note?: string | null }
  | { lotId: string; countedQty: number; note?: string | null };

export type StockDocumentInput = {
  id?: string;
  branchId: string;
  docType: DocType;
  supplierId?: string | null;
  supplierRef?: string | null;
  note?: string | null;
  lines: StockDocumentLineInput[];
};

const toLinePayload = (line: StockDocumentLineInput) => {
  if ("productId" in line) {
    return {
      product_id: line.productId,
      unit_id: line.unitId ?? null,
      lot_no: line.lotNo,
      expiry_date: line.expiryDate,
      qty: line.qty,
      unit_cost: line.unitCost,
      note: line.note ?? null,
    };
  }
  if ("countedQty" in line) return { lot_id: line.lotId, counted_qty: line.countedQty, note: line.note ?? null };
  return { lot_id: line.lotId, qty: line.qty, note: line.note ?? null };
};

/** Creates or replaces a draft; returns its id. */
export const saveStockDocument = async (client: Client, input: StockDocumentInput): Promise<string> =>
  unwrap(
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

export const postStockDocument = async (client: Client, id: string): Promise<void> => {
  const { error } = await client.rpc("post_stock_document", { p_id: id });
  if (error) throw error;
};

export const cancelStockDocument = async (client: Client, id: string, reason?: string): Promise<void> => {
  const { error } = await client.rpc("cancel_stock_document", { p_id: id, p_reason: reason || undefined });
  if (error) throw error;
};
