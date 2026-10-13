import type { ProductUnit, ProductUnitInput } from "@/repositories/products";
import { parseAmount } from "@/views/admin/pos/format";

/** One conversion unit of a variant being edited; numbers stay text while typed. */
export type UnitRow = {
  uid: number;
  id?: string;
  name: string;
  factor: string;
  barcode: string;
  price: string;
  forSale: boolean;
  forPurchase: boolean;
  isActive: boolean;
};

let nextUid = 0;

export const newUnitRow = (init: Partial<Omit<UnitRow, "uid">> = {}): UnitRow => ({
  uid: nextUid++,
  name: "",
  factor: "",
  barcode: "",
  price: "",
  forSale: true,
  forPurchase: false,
  isActive: true,
  ...init,
});

export const toUnitRow = (unit: ProductUnit): UnitRow =>
  newUnitRow({
    id: unit.id,
    name: unit.name,
    factor: String(unit.factor),
    barcode: unit.barcode ?? "",
    price: unit.price === null ? "" : String(unit.price),
    forSale: unit.forSale,
    forPurchase: unit.forPurchase,
    isActive: unit.isActive,
  });

export const toUnitInput = (row: UnitRow): ProductUnitInput => ({
  id: row.id,
  name: row.name.trim(),
  factor: Number(row.factor.replace(",", ".")),
  barcode: row.barcode.trim(),
  price: row.price.trim() ? parseAmount(row.price) : null,
  forSale: row.forSale,
  forPurchase: row.forPurchase,
  isActive: row.isActive,
});

/** The price a unit gets when none is typed: the variant's price times the factor. */
export const autoUnitPrice = (basePrice: number, factor: string): number => {
  const value = Number(factor.replace(",", "."));
  return Number.isFinite(value) && value > 1 ? Math.round(basePrice * value * 100) / 100 : 0;
};

export type UnitProblem = "name" | "duplicate" | "factor" | "";

/** What is wrong with row `index` of a variant's units, if anything. */
export const unitProblem = (rows: readonly UnitRow[], index: number, baseUnit: string): UnitProblem => {
  const row = rows[index];
  const name = row.name.trim().toLowerCase();
  if (!name) return "name";
  if (name === baseUnit.trim().toLowerCase() || rows.some((other, i) => i !== index && other.name.trim().toLowerCase() === name)) {
    return "duplicate";
  }
  const factor = Number(row.factor.replace(",", "."));
  return Number.isFinite(factor) && factor > 1 ? "" : "factor";
};

export const hasUnitProblem = (rows: readonly UnitRow[], baseUnit: string): boolean =>
  rows.some((_, index) => unitProblem(rows, index, baseUnit) !== "");

/** Copies unit definitions onto another variant: new rows, no ids and no barcodes (those are unique). */
export const copyUnitRows = (rows: readonly UnitRow[]): UnitRow[] =>
  rows.map((row) => newUnitRow({ ...row, id: undefined, barcode: "" }));
