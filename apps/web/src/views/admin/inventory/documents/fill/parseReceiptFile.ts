import { readSheet, type CellValue } from "@/lib/data-io/importSchema";
import type { SheetTable } from "@/lib/data-io/readTable";
import { addProblem, type ParsedImport } from "@/lib/data-io/types";
import type { ReceiptFileRow } from "./receiptFileRow";
import { RECEIPT_COLUMNS } from "./receiptFileSchema";

const str = (value: CellValue | undefined): string => (value === null || value === undefined ? "" : String(value));
const num = (value: CellValue | undefined): number | null => (typeof value === "number" ? value : null);

/** Reads the first sheet of a receipt file (Excel or CSV): SKU, quantity and the optional columns. */
export const parseReceiptFile = (sheets: SheetTable[]): ParsedImport<ReceiptFileRow> => {
  const sheet = sheets[0];
  const read = readSheet(sheet?.data ?? [], RECEIPT_COLUMNS);
  const rows = read.rows.map(({ row, values }) => {
    const qty = num(values.qty);
    const cost = num(values.cost);
    if (qty !== null && qty <= 0) addProblem(read.problems, row, "Số lượng phải lớn hơn 0");
    if (cost !== null && cost < 0) addProblem(read.problems, row, "Giá nhập không được âm");
    return {
      row,
      sku: str(values.sku),
      qty,
      unit: str(values.unit),
      cost,
      lotNo: str(values.lot_no),
      expiry: typeof values.expiry === "string" ? values.expiry : null,
    };
  });
  return { rows, problems: read.problems, source: sheet?.data };
};
