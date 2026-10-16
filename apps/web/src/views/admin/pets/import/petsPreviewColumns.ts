import type { PreviewColumn } from "@/composables/useTableImport";
import type { PetImportRow } from "@/types/dataImport";

/** Columns of the preview table of the pet import. */
export const PETS_PREVIEW_COLUMNS: PreviewColumn<PetImportRow>[] = [
  { label: "Số điện thoại chủ", cell: (row) => row.owner_phone },
  { label: "Tên chủ", cell: (row) => row.owner_name },
  { label: "Thú cưng", cell: (row) => row.pet_name },
  { label: "Loài", cell: (row) => row.species },
];
