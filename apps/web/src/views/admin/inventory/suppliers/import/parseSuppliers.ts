import { flagRepeats, readSheet, type CellValue } from "@/lib/data-io/importSchema";
import type { SheetTable } from "@/lib/data-io/readTable";
import type { ParsedImport } from "@/lib/data-io/types";
import type { SupplierImportRow } from "@/types/dataImport";
import { SUPPLIER_COLUMNS } from "./suppliersImportSchema";

const str = (value: CellValue | undefined): string => (value === null || value === undefined ? "" : String(value));

/** Reads the first sheet of a supplier file (Excel or CSV) into rows for `import_suppliers`. */
export const parseSuppliers = (sheets: SheetTable[]): ParsedImport<SupplierImportRow> => {
  const sheet = sheets[0];
  const read = readSheet(sheet?.data ?? [], SUPPLIER_COLUMNS);
  const rows: SupplierImportRow[] = read.rows.map(({ row, values }) => ({
    row,
    name: str(values.name),
    phone: str(values.phone),
    email: str(values.email),
    address: str(values.address),
    tax_code: str(values.tax_code),
    note: str(values.note),
    is_active: typeof values.is_active === "boolean" ? values.is_active : null,
  }));
  flagRepeats(read.rows, "tax_code", "Mã số thuế lặp lại trong file", read.problems);
  // Rows without a tax code are matched by name, so a repeated name is a repeated supplier.
  flagRepeats(
    read.rows.filter((item) => !str(item.values.tax_code)),
    "name",
    "Tên nhà cung cấp lặp lại trong file",
    read.problems
  );
  return { rows, problems: read.problems, source: sheet?.data };
};
