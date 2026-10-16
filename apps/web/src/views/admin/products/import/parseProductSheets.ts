import { addProblem, type ParsedImport } from "@bongcun/core/data-io";
import { flagRepeats, readSheet, type CellValue, type ReadRow } from "@/lib/data-io/importSchema";
import type { SheetTable } from "@/lib/data-io/readTable";
import { IMAGE_SEPARATOR, MAX_ATTRIBUTES, PRODUCT_SHEET, UNIT_SHEET } from "./importTemplate";
import type { ImportRow, ImportUnit } from "@bongcun/core/data-io";
import { PRODUCT_COLUMNS, UNIT_COLUMNS } from "./productImportSchema";

const str = (value: CellValue | undefined): string => (value === null || value === undefined ? "" : String(value));
const num = (value: CellValue | undefined): number | null => (typeof value === "number" ? value : null);

const toUnit = (item: ReadRow): ImportUnit => ({
  name: str(item.values.name),
  factor: num(item.values.factor),
  barcode: str(item.values.barcode),
  price: num(item.values.price),
  for_sale: item.values.for_sale === true,
  for_purchase: item.values.for_purchase === true,
});

/** Reads the unit sheet into units per SKU; its problems are filed under "unit-sheet". */
const readUnits = (data: SheetTable["data"] | undefined, problems: Record<string, string[]>): Map<string, ImportUnit[]> => {
  const bySku = new Map<string, ImportUnit[]>();
  if (!data) return bySku;
  const sheet = readSheet(data, UNIT_COLUMNS);
  for (const [row, notes] of Object.entries(sheet.problems)) {
    if (row === "file") continue;
    for (const note of notes) addProblem(problems, "unit-sheet", `Đơn vị dòng ${row}: ${note}`);
  }
  for (const item of sheet.rows) {
    const sku = str(item.values.sku);
    if (!sku) {
      addProblem(problems, "unit-sheet", `Đơn vị dòng ${item.row}: thiếu SKU`);
      continue;
    }
    bySku.set(sku, [...(bySku.get(sku) ?? []), toUnit(item)]);
  }
  return bySku;
};

const toImportRow = (item: ReadRow, units: Map<string, ImportUnit[]>): ImportRow => {
  const { values } = item;
  const attrs: ImportRow["attrs"] = [];
  for (let i = 1; i <= MAX_ATTRIBUTES; i++) {
    const name = str(values[`attr_name_${i}`]);
    const value = str(values[`attr_value_${i}`]);
    if (name || value) attrs.push({ name, value });
  }
  const sku = str(values.sku);
  return {
    row: item.row,
    group: str(values.group),
    category: str(values.category),
    brand: str(values.brand),
    description: str(values.description),
    images: str(values.images).split(IMAGE_SEPARATOR).map((url) => url.trim()).filter(Boolean),
    attrs,
    sku,
    barcode: str(values.barcode),
    unit: str(values.unit) || "cái",
    price: num(values.price),
    track_stock: values.track_stock !== false,
    is_active: values.is_active !== false,
    units: units.get(sku) ?? [],
  };
};

/**
 * Turns the sheets of a file into rows for the database. An Excel file may have the product sheet and
 * a unit sheet (joined by SKU); a CSV file is the product sheet only. Problems found here are listed
 * per row number; "unit-sheet" collects notes about the unit sheet.
 */
export const parseProductSheets = (sheets: SheetTable[]): ParsedImport<ImportRow> => {
  const products = sheets.find((sheet) => sheet.sheet === PRODUCT_SHEET) ?? sheets[0];
  const unitSheet = sheets.find((sheet) => sheet.sheet === UNIT_SHEET);
  const read = readSheet(products?.data ?? [], PRODUCT_COLUMNS);
  const problems = read.problems;
  const units = readUnits(unitSheet?.data, problems);

  const rows = read.rows.map((item) => toImportRow(item, units));
  flagRepeats(read.rows, "sku", "SKU lặp lại trong file", problems);
  flagRepeats(read.rows, "barcode", "Mã vạch lặp lại trong file", problems);
  for (const sku of units.keys()) {
    if (!rows.some((item) => item.sku === sku)) addProblem(problems, "unit-sheet", `SKU "${sku}" ở sheet đơn vị không có ở sheet sản phẩm`);
  }
  return { rows, problems, source: products?.data };
};
