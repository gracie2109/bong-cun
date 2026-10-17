import { useTableImport } from "@/composables/useTableImport";
import { useImportPets } from "@/features/admin/inventory/queries/dataImports";
import { parsePets } from "./parsePets";
import type { PetImportRow } from "@bongcun/core/data-io";

/** The "Khách và thú cưng" import: the shared flow with the pet file reader and `import_pets`. */
export const usePetsImport = () => {
  const mutation = useImportPets();
  return useTableImport<PetImportRow>({
    parse: parsePets,
    rowNumber: (row) => row.row,
    errorFileBase: "loi-nhap-khach-thu-cung",
    send: (rows, dryRun) => mutation.mutateAsync({ rows, dryRun }),
  });
};
