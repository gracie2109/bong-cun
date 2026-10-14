// Describes the columns of an import file and reads a sheet into typed rows by header name,
// so a file whose columns were moved, or that has extra columns, still imports. Pure TS.

import { isBlankRow, normalizeHeader, text, toDate, toFlag, toNumber, type Cell } from "./cells";
import { addProblem, MAX_IMPORT_ROWS } from "./types";

export type ImportKind = "text" | "number" | "flag" | "date";

export type ImportColumn = {
  key: string;
  /** Header text of the template; a file column with this text (loosely compared) fills the key. */
  header: string;
  /** Other header texts accepted for the same column. */
  aliases?: string[];
  /** The file must have this column, and a row must fill it. */
  required?: boolean;
  /** text when omitted. */
  kind?: ImportKind;
  /** flag columns: the value of an empty cell (false when omitted). */
  defaultFlag?: boolean;
};

export type CellValue = string | number | boolean | null;

/** One non-blank file row: `row` is its line number in the sheet, `values` are read by column key. */
export type ReadRow = { row: string; values: Record<string, CellValue> };

export type ReadTable = {
  rows: ReadRow[];
  /** Row number -> notes; "file" holds notes about the whole file. */
  problems: Record<string, string[]>;
};

/** Column key -> position in the header row. */
export const mapHeaders = (header: readonly Cell[], columns: readonly ImportColumn[]): Map<string, number> => {
  const positions = new Map<string, number>();
  const names = header.map(normalizeHeader);
  for (const column of columns) {
    const wanted = [column.header, ...(column.aliases ?? [])].map(normalizeHeader);
    const index = names.findIndex((name) => wanted.includes(name));
    if (index >= 0) positions.set(column.key, index);
  }
  return positions;
};

const readCell = (column: ImportColumn, cell: Cell, row: string, problems: Record<string, string[]>): CellValue => {
  switch (column.kind) {
    case "number": {
      const value = toNumber(cell);
      if (value === "invalid") addProblem(problems, row, `${column.header} không phải là số`);
      return value === "invalid" ? null : value;
    }
    case "flag": {
      const value = toFlag(cell, column.defaultFlag ?? false);
      if (value === "invalid") addProblem(problems, row, `Cột "${column.header}" chỉ nhận Có hoặc Không`);
      return value === "invalid" ? (column.defaultFlag ?? false) : value;
    }
    case "date": {
      const value = toDate(cell);
      if (value === "invalid") addProblem(problems, row, `${column.header} không phải ngày (dd/mm/yyyy)`);
      return value === "invalid" ? null : value;
    }
    default:
      return text(cell);
  }
};

/**
 * Reads a sheet: the first non-blank line is the header, every later non-blank line is a row.
 * Missing required columns, unreadable cells, empty required cells and too many rows become problems.
 */
export const readSheet = (data: readonly Cell[][], columns: readonly ImportColumn[], maxRows = MAX_IMPORT_ROWS): ReadTable => {
  const problems: Record<string, string[]> = {};
  const headerAt = data.findIndex((cells) => !isBlankRow(cells));
  if (headerAt < 0) {
    addProblem(problems, "file", "File không có dữ liệu");
    return { rows: [], problems };
  }
  const positions = mapHeaders(data[headerAt], columns);
  const missing = columns.filter((column) => column.required && !positions.has(column.key));
  if (missing.length > 0) addProblem(problems, "file", `Thiếu cột: ${missing.map((column) => column.header).join(", ")}`);

  const rows: ReadRow[] = [];
  data.slice(headerAt + 1).forEach((cells, offset) => {
    if (isBlankRow(cells)) return;
    const row = String(headerAt + offset + 2);
    const values: Record<string, CellValue> = {};
    for (const column of columns) {
      const position = positions.get(column.key);
      values[column.key] = readCell(column, position === undefined ? undefined : cells[position], row, problems);
      if (column.required && positions.has(column.key) && (values[column.key] === "" || values[column.key] === null)) {
        addProblem(problems, row, `Thiếu ${column.header}`);
      }
    }
    rows.push({ row, values });
  });

  if (rows.length === 0 && missing.length === 0) addProblem(problems, "file", "File không có dòng dữ liệu nào");
  if (rows.length > maxRows) addProblem(problems, "file", `File có ${rows.length} dòng, tối đa ${maxRows} dòng mỗi lần`);
  return { rows, problems };
};

/** Adds a note to every row whose value of `key` already appeared on an earlier row. */
export const flagRepeats = (rows: readonly ReadRow[], key: string, note: string, problems: Record<string, string[]>): void => {
  const seen = new Set<string>();
  for (const item of rows) {
    const value = String(item.values[key] ?? "").trim().toLowerCase();
    if (!value) continue;
    if (seen.has(value)) addProblem(problems, item.row, `${note}: ${item.values[key]}`);
    seen.add(value);
  }
};

/** Header row plus example rows of the template, in the order of `columns`. */
export const templateRows = (columns: readonly ImportColumn[], samples: readonly (readonly (string | number)[])[]): (string | number)[][] => [
  columns.map((column) => column.header),
  ...samples.map((sample) => [...sample]),
];
