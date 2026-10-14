// Shared description of an exported table column (Excel, CSV and PDF read the same list).

export type CellKind = "text" | "number" | "money" | "date" | "datetime" | "flag";

export type CellValue = string | number | boolean | Date | null | undefined;

export type ExportColumn<T> = {
  /** Vietnamese header text. */
  header: string;
  value: (row: T) => CellValue;
  /** How the value is written; text when omitted. */
  kind?: CellKind;
  /** Excel column width in characters. */
  width?: number;
  /** PDF only: add the column up in the totals line. */
  sum?: boolean;
};

export type ExportFormat = "xlsx" | "csv" | "pdf";

/** Rows an Excel or CSV file may hold, and rows a printed PDF may hold. */
export const EXPORT_ROW_LIMIT = 10_000;
export const EXPORT_PDF_ROW_LIMIT = 1_000;
/** Rows asked from a list function per call while exporting. */
export const EXPORT_PAGE_SIZE = 500;
