import type { ExportColumn } from "./columns";
import { formatCell } from "./formatCell";

/** UTF-8 byte order mark: Excel needs it to read Vietnamese correctly. */
const BOM = "﻿";

// Cells that start like this are read as formulas by Excel; a leading quote keeps them text.
const FORMULA_START = /^[=+\-@\t\r]/;

const escapeCell = (text: string, kind?: string): string => {
  const safe = kind === "number" || kind === "money" ? text : FORMULA_START.test(text) ? `'${text}` : text;
  return /[",\r\n]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe;
};

/** The CSV text (with BOM and CRLF line ends) of rows under the given columns. */
export const writeCsv = <T>(rows: readonly T[], columns: readonly ExportColumn<T>[]): string => {
  const lines = [
    columns.map((column) => escapeCell(column.header)).join(","),
    ...rows.map((row) => columns.map((column) => escapeCell(formatCell(column.value(row), column.kind, "csv"), column.kind)).join(",")),
  ];
  return BOM + lines.join("\r\n");
};
