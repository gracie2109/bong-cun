// Domain types of the stock module; the repositories and their mappers share them.
import type { ProductUnit } from "@bongcun/core/products";

import type { DocType } from "@bongcun/core/inventory";

export { DOC_TYPES, type DocType, type StockDocumentInput, type StockDocumentLineInput } from "@bongcun/core/inventory";

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

export type StockDocumentFilter = {
  branchId: string;
  docType?: DocType;
  status?: DocStatus;
  /** Document code, supplier reference or note. */
  search?: string;
};

export const STOCK_STATUSES = ["all", "low", "out", "expiring", "expired"] as const;
export type StockStatus = (typeof STOCK_STATUSES)[number];
export type StockAlertStatus = Exclude<StockStatus, "all">;

/** Days ahead that count as "expiring soon". */
export const EXPIRY_WINDOWS = [30, 60, 90] as const;

export type StockRow = {
  productId: string;
  name: string;
  sku: string | null;
  barcode: string | null;
  unit: string;
  isActive: boolean;
  onHand: number;
  /** Unexpired stock: what a sale can take. */
  sellable: number;
  expired: number;
  expiring: number;
  nextExpiry: string | null;
  stockValue: number;
  minQty: number | null;
};

export type StockFilter = {
  branchId: string;
  search?: string;
  status?: StockStatus;
  expiryDays?: number;
};

export type StockAlertCounts = Record<StockAlertStatus, number>;

export type StockLot = {
  id: string;
  productId: string;
  lotNo: string;
  expiryDate: string | null;
  unitCost: number;
  qtyOnHand: number;
  receivedAt: string;
};

export const MOVEMENT_REASONS = [
  "receipt",
  "receipt_cancel",
  "sale",
  "sale_cancel",
  "return",
  "writeoff",
  "count",
] as const;
export type MovementReason = (typeof MOVEMENT_REASONS)[number];

export type StockMovement = {
  id: string;
  createdAt: string;
  reason: MovementReason;
  qty: number;
  balanceAfter: number;
  unitCost: number;
  lotNo: string;
  expiryDate: string | null;
  /** The document, invoice or return code it came from. */
  ref: string | null;
};
