// Input contract of the stock document functions (save, post, cancel). Camel-case on this side;
// the Supabase adapter writes the snake-case `jsonb` that `save_stock_document` reads.
import { z } from "zod";

export const DOC_TYPES = ["receipt", "writeoff", "count"] as const;
export const docType = z.enum(DOC_TYPES);
export type DocType = z.infer<typeof docType>;

const uuid = z.string().uuid();

/** A receipt line names a lot; write-off and count lines point at an existing one. */
export const receiptLineInput = z.object({
  productId: uuid,
  /** The conversion unit qty and unitCost are in; missing: the base unit. */
  unitId: uuid.nullish(),
  lotNo: z.string(),
  expiryDate: z.string().nullable(),
  qty: z.number().positive(),
  unitCost: z.number().min(0),
  note: z.string().nullish(),
});

export const writeoffLineInput = z.object({ lotId: uuid, qty: z.number().positive(), note: z.string().nullish() });
export const countLineInput = z.object({ lotId: uuid, countedQty: z.number().min(0), note: z.string().nullish() });

export const stockDocumentLineInput = z.union([receiptLineInput, countLineInput, writeoffLineInput]);
export type StockDocumentLineInput = z.infer<typeof stockDocumentLineInput>;

/** Creates (no `id`) or replaces a draft. */
export const stockDocumentInput = z.object({
  id: uuid.optional(),
  branchId: uuid,
  docType,
  supplierId: uuid.nullish(),
  supplierRef: z.string().nullish(),
  note: z.string().nullish(),
  lines: z.array(stockDocumentLineInput),
});
export type StockDocumentInput = z.infer<typeof stockDocumentInput>;

export const postStockDocumentInput = z.object({ id: uuid });
export const cancelStockDocumentInput = z.object({ id: uuid, reason: z.string().optional() });
