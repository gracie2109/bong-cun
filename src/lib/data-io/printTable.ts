import { escapeHtml, printHtml } from "../print";
import { EXPORT_PDF_ROW_LIMIT, type ExportColumn } from "./columns";
import { formatCell } from "./formatCell";

export type PrintTableInput<T> = {
  title: string;
  /** Lines under the title: branch, filters, who exported and when. */
  meta?: string[];
  columns: readonly ExportColumn<T>[];
  rows: readonly T[];
  /** Text for the line under the table, e.g. "134 dòng". */
  rowCountLabel?: string;
};

const WIDE_COLUMNS = 6;
const RIGHT_ALIGNED = new Set(["number", "money"]);

const head = <T>(columns: readonly ExportColumn<T>[]): string =>
  `<tr>${columns.map((c) => `<th class="${RIGHT_ALIGNED.has(c.kind ?? "") ? "r" : ""}">${escapeHtml(c.header)}</th>`).join("")}</tr>`;

const bodyRow = <T>(row: T, columns: readonly ExportColumn<T>[]): string =>
  `<tr>${columns
    .map((c) => `<td class="${RIGHT_ALIGNED.has(c.kind ?? "") ? "r" : ""}">${escapeHtml(formatCell(c.value(row), c.kind, "print"))}</td>`)
    .join("")}</tr>`;

const totalsRow = <T>(rows: readonly T[], columns: readonly ExportColumn<T>[]): string => {
  if (!columns.some((c) => c.sum)) return "";
  const cells = columns.map((c, index) => {
    if (!c.sum) return `<td>${index === 0 ? "Tổng" : ""}</td>`;
    const total = rows.reduce((sum, row) => sum + (Number(c.value(row)) || 0), 0);
    return `<td class="r">${escapeHtml(formatCell(total, c.kind, "print"))}</td>`;
  });
  return `<tr class="total">${cells.join("")}</tr>`;
};

/** The HTML page of a table, ready for the browser's "Save as PDF". */
export const tableHtml = <T>({ title, meta = [], columns, rows, rowCountLabel }: PrintTableInput<T>): string => {
  const landscape = columns.length > WIDE_COLUMNS ? "landscape" : "portrait";
  return `<!doctype html><html lang="vi"><head><meta charset="utf-8"><title>${escapeHtml(title)}</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;600;700&display=swap">
<style>
  @page { size: A4 ${landscape}; margin: 10mm; }
  body { font-family: "Be Vietnam Pro", Arial, sans-serif; font-size: 10px; color: #0f172a; margin: 0; }
  h1 { font-size: 16px; margin: 0 0 4px; }
  .meta { color: #475569; margin: 0 0 2px; }
  table { width: 100%; border-collapse: collapse; margin-top: 8px; }
  thead { display: table-header-group; }
  tr { page-break-inside: avoid; }
  th, td { border: 1px solid #cbd5e1; padding: 3px 5px; text-align: left; vertical-align: top; }
  th { background: #f1f5f9; font-weight: 700; }
  .r { text-align: right; white-space: nowrap; }
  .total td { font-weight: 700; background: #f8fafc; }
  .count { margin-top: 6px; color: #475569; }
</style></head><body>
  <h1>${escapeHtml(title)}</h1>
  ${meta.map((line) => `<p class="meta">${escapeHtml(line)}</p>`).join("")}
  <table><thead>${head(columns)}</thead><tbody>${rows.map((row) => bodyRow(row, columns)).join("")}${totalsRow(rows, columns)}</tbody></table>
  ${rowCountLabel ? `<p class="count">${escapeHtml(rowCountLabel)}</p>` : ""}
</body></html>`;
};

/** Opens the print dialog for a table (at most EXPORT_PDF_ROW_LIMIT rows are expected). */
export const printTable = <T>(input: PrintTableInput<T>): void => printHtml(tableHtml({ ...input, rows: input.rows.slice(0, EXPORT_PDF_ROW_LIMIT) }));
