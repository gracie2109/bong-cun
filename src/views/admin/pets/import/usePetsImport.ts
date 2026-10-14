import { useTableImport } from "@/composables/useTableImport";
import { useImportPets } from "@/queries/dataImports";
import { parsePets } from "./parsePets";
import type { PetImportRow } from "./petsImportRow";

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
