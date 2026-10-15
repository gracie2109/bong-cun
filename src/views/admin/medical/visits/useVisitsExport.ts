import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { listMedicalVisits } from "@/repositories/medical";
import type { VisitFilter } from "@/types/medicalVisit";
import { visitsExportColumns } from "./visitsExportColumns";

// list_medical_visits serves 100 rows per page at most.
const PAGE_SIZE = 100;

/** Export of the medical visits of one branch under the filter the list is showing. */
export const useVisitsExport = (branchId: Ref<string | undefined>, filter: Ref<VisitFilter>, branchName: () => string | undefined) =>
  useTableExport({
    name: "Lượt khám",
    permission: "medical",
    columns: visitsExportColumns,
    pageSize: PAGE_SIZE,
    enabled: () => !!branchId.value,
    fetchPage: (pageIndex, pageSize) => {
      if (!branchId.value) return Promise.resolve({ rows: [], total: 0 });
      return listMedicalVisits(supabaseClient(), branchId.value, { pageIndex, pageSize }, filter.value);
    },
    meta: () => {
      const { from, to } = filter.value;
      return [branchName() ? `Cơ sở: ${branchName()}` : "", from || to ? `Ngày: ${from ?? "…"} - ${to ?? "…"}` : ""].filter(Boolean);
    },
  });
