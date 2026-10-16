import type { SkuProduct } from "@/repositories/dataImports";
import type { ImportRowResult } from "@/lib/data-io/types";
import { blankLine, type EditLine } from "../documentLines";
import type { ReceiptFileRow } from "./receiptFileRow";

const same = (a: string, b: string): boolean => a.trim().toLowerCase() === b.trim().toLowerCase();

/** Turns one file row into a receipt line, or says what is wrong with it. */
export const resolveReceiptRow = (row: ReceiptFileRow, product: SkuProduct | undefined): { line?: EditLine; error?: string } => {
  if (!product) return { error: `Không có sản phẩm nào đang bán với SKU "${row.sku}"` };
  if (!product.trackStock) return { error: "Sản phẩm này không theo dõi kho" };

  const buyUnits = product.units.filter((unit) => unit.forPurchase);
  let unitId: string | null = null;
  if (row.unit && !same(row.unit, product.unit)) {
    const unit = buyUnits.find((item) => same(item.name, row.unit));
    if (!unit) {
      const allowed = [product.unit, ...buyUnits.map((item) => item.name)].join(", ");
      return { error: `Đơn vị "${row.unit}" không dùng để nhập kho; chọn một trong: ${allowed}` };
    }
    unitId = unit.id;
  }

  const line = blankLine({
    id: product.productId,
    name: product.name,
    unit: product.unit,
    units: product.units.map((unit) => ({ ...unit, barcode: null, price: null, forSale: true, isActive: true })),
  });
  // A file row without a unit is entered in the base unit, not in the unit a fresh line would pick.
  line.unitId = unitId;
  line.qty = String(row.qty ?? "");
  line.unitCost = row.cost === null ? "" : String(Math.round(row.cost));
  line.lotNo = row.lotNo;
  line.expiryDate = row.expiry ?? "";
  return { line };
};

/** The preview answer of the lookup, one entry per file row. */
export const toRowResult = (row: ReceiptFileRow, error: string | undefined): ImportRowResult => ({
  row: row.row,
  action: error ? "skip" : "create",
  errors: error ? [error] : [],
});
