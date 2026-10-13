// CSV text and download. Pure TS (the download touches the DOM only when called).

export type CsvColumn<T> = {
  header: string;
  /** Numbers are written raw, so Excel reads them as numbers. */
  value: (row: T) => string | number | null | undefined;
};

/** UTF-8 byte order mark: Excel needs it to read Vietnamese correctly. */
const BOM = "﻿";

const escapeCell = (value: string | number | null | undefined): string => {
  const text = value === null || value === undefined ? "" : String(value);
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
};

/** The CSV text (with BOM and CRLF line ends) of rows under the given columns. */
export const toCsv = <T>(rows: readonly T[], columns: readonly CsvColumn<T>[]): string => {
  const lines = [
    columns.map((column) => escapeCell(column.header)).join(","),
    ...rows.map((row) => columns.map((column) => escapeCell(column.value(row))).join(",")),
  ];
  return BOM + lines.join("\r\n");
};

export const downloadCsv = (fileName: string, text: string): void => {
  const url = URL.createObjectURL(new Blob([text], { type: "text/csv;charset=utf-8" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = fileName;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
};
