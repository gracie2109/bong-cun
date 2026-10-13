import type { CellValue, SheetData } from "read-excel-file/browser";

type Cell = CellValue<number> | null | undefined;
import type { ImportRow, ImportUnit, ParsedFile } from "./importTypes";
import { IMAGE_SEPARATOR, MAX_ATTRIBUTES, MAX_FILE_ROWS } from "./importTemplate";

const text = (value: Cell): string => (value == null ? "" : String(value).trim());

const isBlankRow = (cells: readonly Cell[]): boolean => cells.every((cell) => text(cell) === "");

/** Reads a number typed with a dot or a comma ("1.000" is not guessed: use plain digits). */
const toNumber = (value: Cell): number | null | "invalid" => {
  if (typeof value === "number") return value;
  const raw = text(value);
  if (raw === "") return null;
  const parsed = Number(raw.replace(/\s/g, "").replace(",", "."));
  return Number.isFinite(parsed) ? parsed : "invalid";
};

/** "Có"/"Không" (also yes/no, 1/0, true/false); empty gives the default. */
const toFlag = (value: Cell, fallback: boolean): boolean | "invalid" => {
  if (typeof value === "boolean") return value;
  const raw = text(value).toLowerCase();
  if (raw === "") return fallback;
  if (["có", "co", "yes", "y", "1", "true", "x"].includes(raw)) return true;
  if (["không", "khong", "no", "n", "0", "false"].includes(raw)) return false;
  return "invalid";
};

const addProblem = (problems: Record<string, string[]>, row: string, note: string) => {
  (problems[row] ??= []).push(note);
};

const parseUnits = (data: SheetData | undefined, problems: Record<string, string[]>): Map<string, ImportUnit[]> => {
  const bySku = new Map<string, ImportUnit[]>();
  (data ?? []).slice(1).forEach((cells, index) => {
    if (isBlankRow(cells)) return;
    const line = `Đơn vị dòng ${index + 2}`;
    const sku = text(cells[0]);
    const factor = toNumber(cells[2]);
    const price = toNumber(cells[4]);
    const sale = toFlag(cells[5], true);
    const purchase = toFlag(cells[6], false);
    if (!sku) return void addProblem(problems, "unit-sheet", `${line}: thiếu SKU`);
    if (factor === "invalid" || price === "invalid" || sale === "invalid" || purchase === "invalid") {
      return void addProblem(problems, "unit-sheet", `${line}: có ô không đọc được`);
    }
    const unit: ImportUnit = {
      name: text(cells[1]),
      factor,
      barcode: text(cells[3]),
      price,
      for_sale: sale,
      for_purchase: purchase,
    };
    bySku.set(sku, [...(bySku.get(sku) ?? []), unit]);
  });
  return bySku;
};

/** Notes every row whose SKU / barcode already appeared on an earlier row, whichever group it is in. */
const flagRepeats = (rows: ImportRow[], field: "sku" | "barcode", note: string, problems: Record<string, string[]>) => {
  const seen = new Set<string>();
  for (const item of rows) {
    const value = item[field];
    if (!value) continue;
    if (seen.has(value)) addProblem(problems, item.row, `${note}: ${value}`);
    seen.add(value);
  }
};

/**
 * Turns the product sheet (and the optional unit sheet, joined by SKU) into rows for the database.
 * Problems found here are listed per row number; "unit-sheet" collects notes about the unit sheet.
 */
export const parseSheets = (products: SheetData, unitSheet?: SheetData): ParsedFile => {
  const problems: Record<string, string[]> = {};
  const units = parseUnits(unitSheet, problems);
  const rows: ImportRow[] = [];

  products.slice(1).forEach((cells, index) => {
    if (isBlankRow(cells)) return;
    const row = String(index + 2);
    const price = toNumber(cells[14]);
    const track = toFlag(cells[15], true);
    const active = toFlag(cells[16], true);
    if (price === "invalid") addProblem(problems, row, "Giá không phải là số");
    if (track === "invalid") addProblem(problems, row, 'Cột "Theo dõi kho" chỉ nhận Có hoặc Không');
    if (active === "invalid") addProblem(problems, row, 'Cột "Đang bán" chỉ nhận Có hoặc Không');

    const attrs: ImportRow["attrs"] = [];
    for (let i = 0; i < MAX_ATTRIBUTES; i++) {
      const name = text(cells[5 + i * 2]);
      const value = text(cells[6 + i * 2]);
      if (name || value) attrs.push({ name, value });
    }
    const sku = text(cells[11]);
    rows.push({
      row,
      group: text(cells[0]),
      category: text(cells[1]),
      brand: text(cells[2]),
      description: text(cells[3]),
      images: text(cells[4]).split(IMAGE_SEPARATOR).map((url) => url.trim()).filter(Boolean),
      attrs,
      sku,
      barcode: text(cells[12]),
      unit: text(cells[13]) || "cái",
      price: price === "invalid" ? null : price,
      track_stock: track === "invalid" ? true : track,
      is_active: active === "invalid" ? true : active,
      units: units.get(sku) ?? [],
    });
  });

  flagRepeats(rows, "sku", "SKU lặp lại trong file", problems);
  flagRepeats(rows, "barcode", "Mã vạch lặp lại trong file", problems);
  if (rows.length > MAX_FILE_ROWS) addProblem(problems, "file", `File có ${rows.length} dòng, tối đa ${MAX_FILE_ROWS} dòng mỗi lần`);
  if (rows.length === 0) addProblem(problems, "file", "Không có dòng sản phẩm nào");
  for (const sku of units.keys()) {
    if (!rows.some((item) => item.sku === sku)) addProblem(problems, "unit-sheet", `SKU "${sku}" ở sheet đơn vị không có ở sheet sản phẩm`);
  }
  return { rows, problems };
};
