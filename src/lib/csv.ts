// CSV helpers kept for the screens that already import them; the code lives in lib/data-io.
import type { ExportColumn } from "./data-io/columns";
import { writeCsv } from "./data-io/csvWrite";

export type CsvColumn<T> = ExportColumn<T>;

/** The CSV text (with BOM and CRLF line ends) of rows under the given columns. */
export const toCsv = writeCsv;

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
