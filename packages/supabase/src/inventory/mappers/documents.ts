// Rows of stock documents -> domain types. Pure: no client, no Vue.
import type { Tables } from "@bongcun/supabase/db";
import { DOC_TYPES, type DocType } from "@bongcun/core/inventory";
import { toUnit } from "../../products/mappers";
import { num } from "../helpers";
import {
  DOC_STATUSES,
  type DocStatus,
  type StockDocument,
  type StockDocumentDetail,
  type StockDocumentLine,
  type StockDocumentLineInput,
} from "../types";

export type DocumentRow = Tables<"stock_documents"> & { suppliers: { name: string } | null };
export type DocumentLineRow = Tables<"stock_document_lines"> & {
  products: { name: string; unit: string; product_units: Tables<"product_units">[] } | null;
};

const toDocType = (value: string): DocType => DOC_TYPES.find((type) => type === value) ?? "receipt";
const toDocStatus = (value: string): DocStatus => DOC_STATUSES.find((status) => status === value) ?? "draft";

export const toDocument = (row: DocumentRow): StockDocument => ({
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

const optionalNum = (value: number | null): number | null => (value === null ? null : num(value));

export const toDocumentLine = (line: DocumentLineRow): StockDocumentLine => ({
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
  enteredQty: optionalNum(line.entered_qty),
  enteredCost: optionalNum(line.entered_cost),
  productUnits: (line.products?.product_units ?? []).map(toUnit),
  systemQty: optionalNum(line.system_qty),
  countedQty: optionalNum(line.counted_qty),
  note: line.note,
});

export const toDocumentDetail = (row: DocumentRow & { stock_document_lines: DocumentLineRow[] }): StockDocumentDetail => ({
  ...toDocument(row),
  lines: [...row.stock_document_lines].sort((a, b) => a.line_no - b.line_no).map(toDocumentLine),
});

/** The snake-case `jsonb` one line of `save_stock_document` reads. */
export const toLinePayload = (line: StockDocumentLineInput) => {
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
