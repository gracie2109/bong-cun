import type { Cell } from "./cells";
import { decodeCsvBytes, parseCsv } from "./csvRead";

/** One sheet of an imported file; a CSV file has a single sheet named after the file. */
export type SheetTable = { sheet: string; data: Cell[][] };

export class UnsupportedFileError extends Error {}

/** Reads an .xlsx or .csv file in the browser. The Excel reader loads only when needed. */
export const readTable = async (file: File): Promise<SheetTable[]> => {
  const name = file.name.toLowerCase();
  if (name.endsWith(".csv")) {
    return [{ sheet: file.name, data: parseCsv(decodeCsvBytes(await file.arrayBuffer())) }];
  }
  if (name.endsWith(".xlsx")) {
    const { default: readXlsxFile } = await import("read-excel-file/browser");
    const sheets = await readXlsxFile(file);
    return sheets.map((sheet) => ({ sheet: sheet.sheet, data: sheet.data as Cell[][] }));
  }
  throw new UnsupportedFileError(file.name);
};
