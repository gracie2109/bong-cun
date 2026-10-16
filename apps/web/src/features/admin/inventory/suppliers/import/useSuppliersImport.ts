import { useTableImport } from "@/composables/useTableImport";
import { useImportSuppliers } from "@/queries/dataImports";
import { parseSuppliers } from "./parseSuppliers";
import type { SupplierImportRow } from "@bongcun/core/data-io";

/** The supplier import: the shared flow with the supplier file reader and `import_suppliers`. */
export const useSuppliersImport = () => {
  const mutation = useImportSuppliers();
  return useTableImport<SupplierImportRow>({
    parse: parseSuppliers,
    rowNumber: (row) => row.row,
    errorFileBase: "loi-nhap-nha-cung-cap",
    send: (rows, dryRun) => mutation.mutateAsync({ rows, dryRun }),
  });
};
