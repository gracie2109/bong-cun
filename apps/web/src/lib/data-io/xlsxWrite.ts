import type { Cell, SheetData } from "write-excel-file/browser";
import type { CellKind, ExportColumn } from "./columns";

const FORMATS: Partial<Record<CellKind, string>> = {
  money: "#,##0",
  number: "#,##0.##",
  date: "dd/mm/yyyy",
  datetime: "dd/mm/yyyy hh:mm",
};

const DEFAULT_WIDTH = 16;

const toDate = (value: unknown): Date | null => {
  if (value === null || value === undefined || value === "") return null;
  const date = value instanceof Date ? value : new Date(value as string | number);
  return Number.isNaN(date.getTime()) ? null : date;
};

// A date-only string becomes local midnight, so the day does not move with the time zone.
const parseDay = (value: unknown): Date | null => {
  const match = typeof value === "string" ? /^(\d{4})-(\d{2})-(\d{2})$/.exec(value) : null;
  return match ? new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3])) : toDate(value);
};

const cellOf = <T>(row: T, column: ExportColumn<T>): Cell => {
  const raw = column.value(row);
  if (raw === null || raw === undefined || raw === "") return null;
  switch (column.kind) {
    case "number":
    case "money": {
      const amount = Number(raw);
      return Number.isNaN(amount) ? { value: String(raw), type: String } : { value: amount, type: Number, format: FORMATS[column.kind] };
    }
    case "date":
    case "datetime": {
      const date = parseDay(raw);
      return date ? { value: date, type: Date, format: FORMATS[column.kind] } : { value: String(raw), type: String };
    }
    case "flag":
      return { value: raw ? "Có" : "Không", type: String };
    default:
      return { value: String(raw), type: String };
  }
};

/** Writes rows to an .xlsx file in the browser (header bold and frozen, formats per column kind). */
export const writeXlsx = async <T>(
  rows: readonly T[],
  columns: readonly ExportColumn<T>[],
  fileName: string,
  sheetName: string,
): Promise<void> => {
  const { default: writeXlsxFile } = await import("write-excel-file/browser");
  const header: Cell[] = columns.map((column) => ({ value: column.header, fontWeight: "bold" as const }));
  const data: SheetData = [header, ...rows.map((row) => columns.map((column) => cellOf(row, column)))];
  await writeXlsxFile(data, {
    sheet: sheetName.slice(0, 31),
    columns: columns.map((column) => ({ width: column.width ?? DEFAULT_WIDTH })),
    stickyRowsCount: 1,
  }).toFile(fileName);
};
