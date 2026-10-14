import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { listSuppliers, type SupplierFilter } from "@/repositories/inventory";
import { suppliersExportColumns } from "./suppliersExportColumns";

/** Export of the suppliers under the filter the list is showing (Excel and CSV only). */
export const useSuppliersExport = (filter: Ref<SupplierFilter>) =>
  useTableExport({
    name: "Nhà cung cấp",
    permission: "inventory",
    columns: suppliersExportColumns,
    formats: ["xlsx", "csv"],
    fetchPage: (pageIndex, pageSize) => listSuppliers(supabaseClient(), { pageIndex, pageSize }, filter.value),
  });
