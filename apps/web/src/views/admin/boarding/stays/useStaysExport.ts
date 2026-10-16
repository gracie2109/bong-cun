import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { listBoardingStays } from "@bongcun/supabase/boarding";
import type { StayFilter } from "@bongcun/core/boarding";
import { staysExportColumns } from "./staysExportColumns";

// list_boarding_stays serves 100 rows per page at most.
const PAGE_SIZE = 100;

/** Export of the boarding stays of one branch under the filter the list is showing. */
export const useStaysExport = (branchId: Ref<string | undefined>, filter: Ref<StayFilter>, branchName: () => string | undefined) =>
  useTableExport({
    name: "Lượt lưu trú",
    permission: "boarding",
    columns: staysExportColumns,
    pageSize: PAGE_SIZE,
    enabled: () => !!branchId.value,
    fetchPage: (pageIndex, pageSize) => {
      if (!branchId.value) return Promise.resolve({ rows: [], total: 0 });
      return listBoardingStays(supabaseClient(), branchId.value, { pageIndex, pageSize }, filter.value);
    },
    meta: () => {
      const { from, to } = filter.value;
      return [branchName() ? `Cơ sở: ${branchName()}` : "", from || to ? `Ngày: ${from ?? "…"} - ${to ?? "…"}` : ""].filter(Boolean);
    },
  });
