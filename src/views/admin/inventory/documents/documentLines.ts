import type { DocType, StockLot, StockDocumentLineInput } from "@/repositories/inventory";
import { parseAmount } from "@/views/admin/pos/format";
import { parseQty } from "../format";

/** One editable row. Text fields hold what was typed; numbers are parsed on save. */
export type EditLine = {
  key: string;
  productId: string;
  productName: string;
  unit: string;
  lotId: string | null;
  lotNo: string;
  expiryDate: string;
  qty: string;
  unitCost: string;
  countedQty: string;
  systemQty: number | null;
  lotOptions: StockLot[];
};

let keySeq = 0;

export const blankLine = (product: { id: string; name: string; unit: string }): EditLine => ({
  key: `line-${++keySeq}`,
  productId: product.id,
  productName: product.name,
  unit: product.unit,
  lotId: null,
  lotNo: "",
  expiryDate: "",
  qty: "",
  unitCost: "",
  countedQty: "",
  systemQty: null,
  lotOptions: [],
});

export const selectedLot = (line: EditLine): StockLot | undefined =>
  line.lotOptions.find((lot) => lot.id === line.lotId);

/** Points a line at one of its lot options, taking over the lot's number, expiry and cost. */
export const pickLot = (line: EditLine, lotId: string) => {
  const lot = line.lotOptions.find((item) => item.id === lotId);
  line.lotId = lotId;
  line.lotNo = lot?.lotNo ?? "";
  line.expiryDate = lot?.expiryDate ?? "";
  line.unitCost = String(lot?.unitCost ?? 0);
};

export const lineCost = (type: DocType, line: EditLine): number =>
  type === "receipt" ? parseAmount(line.unitCost) : Number(line.unitCost) || 0;

export const lineAmount = (type: DocType, line: EditLine): number => {
  const value = parseQty(line.qty);
  return Number.isFinite(value) ? Math.round(value * lineCost(type, line)) : 0;
};

/** Counted minus system quantity, or null until both are known. */
export const countDiff = (line: EditLine): number | null => {
  const counted = parseQty(line.countedQty);
  return Number.isFinite(counted) && line.systemQty !== null ? Math.round((counted - line.systemQty) * 100) / 100 : null;
};

export const diffTone = (value: number | null): string => (!value ? "" : value > 0 ? "text-primary" : "text-red-600");

/** Value of a draft: the counted difference at cost for a count, the amounts otherwise. */
export const draftTotal = (type: DocType, lines: readonly EditLine[]): number =>
  type === "count"
    ? lines.reduce((sum, line) => sum + Math.round((countDiff(line) ?? 0) * (Number(line.unitCost) || 0)), 0)
    : lines.reduce((sum, line) => sum + lineAmount(type, line), 0);

export const validQty = (type: DocType, line: EditLine): boolean => {
  const value = parseQty(line.qty);
  if (!Number.isFinite(value) || value <= 0) return false;
  const lot = selectedLot(line);
  return type !== "writeoff" || (!!line.lotId && (!lot || value <= lot.qtyOnHand));
};

export const validCounted = (line: EditLine): boolean => {
  const value = parseQty(line.countedQty);
  return Number.isFinite(value) && value >= 0;
};

export const validLine = (type: DocType, line: EditLine): boolean =>
  type === "count" ? validCounted(line) : validQty(type, line);

export const toInput = (type: DocType, line: EditLine): StockDocumentLineInput => {
  if (type === "receipt") {
    return {
      productId: line.productId,
      lotNo: line.lotNo.trim(),
      expiryDate: line.expiryDate || null,
      qty: parseQty(line.qty),
      unitCost: parseAmount(line.unitCost),
    };
  }
  if (type === "count") return { lotId: line.lotId as string, countedQty: parseQty(line.countedQty) };
  return { lotId: line.lotId as string, qty: parseQty(line.qty) };
};
