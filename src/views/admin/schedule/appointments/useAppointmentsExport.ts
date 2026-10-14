import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { listAppointments, type AppointmentFilter } from "@/repositories/spa";
import { appointmentsExportColumns } from "./appointmentsExportColumns";

// list_appointments serves 100 rows per page at most.
const PAGE_SIZE = 100;

/** Export of the spa appointments of one branch under the filter the list is showing. */
export const useAppointmentsExport = (
  branchId: Ref<string | undefined>,
  filter: Ref<AppointmentFilter>,
  branchName: () => string | undefined
) =>
  useTableExport({
    name: "Lịch hẹn spa",
    permission: "schedule",
    columns: appointmentsExportColumns,
    pageSize: PAGE_SIZE,
    enabled: () => !!branchId.value,
    fetchPage: (pageIndex, pageSize) => {
      if (!branchId.value) return Promise.resolve({ rows: [], total: 0 });
      return listAppointments(supabaseClient(), branchId.value, { pageIndex, pageSize }, filter.value);
    },
    meta: () => {
      const { from, to } = filter.value;
      return [branchName() ? `Cơ sở: ${branchName()}` : "", from || to ? `Ngày: ${from ?? "…"} - ${to ?? "…"}` : ""].filter(Boolean);
    },
  });
