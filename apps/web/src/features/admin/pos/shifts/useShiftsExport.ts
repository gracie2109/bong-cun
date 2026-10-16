import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { listShifts } from "@bongcun/supabase/pos";
import { shiftsExportColumns } from "./shiftsExportColumns";

/** Export of the cashier shifts of one branch. */
export const useShiftsExport = (branchId: Ref<string | undefined>, branchName: () => string | undefined) =>
  useTableExport({
    name: "Ca thu ngân",
    permission: "pos",
    columns: shiftsExportColumns,
    enabled: () => !!branchId.value,
    fetchPage: (pageIndex, pageSize) => {
      if (!branchId.value) return Promise.resolve({ rows: [], total: 0 });
      return listShifts(supabaseClient(), branchId.value, { pageIndex, pageSize });
    },
    meta: () => (branchName() ? [`Cơ sở: ${branchName()}`] : []),
  });
