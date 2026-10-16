import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { listPetServices, type PetServiceFilter } from "@bongcun/supabase/spa";
import { servicesExportColumns } from "./servicesExportColumns";

/** Export of the services under the filter the list is showing (Excel and CSV only). */
export const useServicesExport = (filter: Ref<PetServiceFilter>) =>
  useTableExport({
    name: "Dịch vụ",
    permission: "petServices",
    columns: servicesExportColumns,
    formats: ["xlsx", "csv"],
    fetchPage: (pageIndex, pageSize) => listPetServices(supabaseClient(), { pageIndex, pageSize }, filter.value),
  });
