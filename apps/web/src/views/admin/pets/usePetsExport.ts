import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { listPets, type PetListFilter } from "@/repositories/pets";
import { petsExportColumns } from "./petsExportColumns";

/** Export of the pets (with their owner) under the filter the list is showing. */
export const usePetsExport = (filter: Ref<PetListFilter>) =>
  useTableExport({
    name: "Thú cưng",
    permission: "pets",
    columns: petsExportColumns,
    fetchPage: (pageIndex, pageSize) => listPets(supabaseClient(), { pageIndex, pageSize }, filter.value),
    meta: () => (filter.value.search ? [`Tìm: ${filter.value.search}`] : []),
  });
