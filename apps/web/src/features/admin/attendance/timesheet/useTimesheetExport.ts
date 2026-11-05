import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { getTimesheet } from "@bongcun/supabase/attendance";
import type { TimesheetFilter } from "@bongcun/supabase/attendance";
import { timesheetExportColumns } from "./timesheetExportColumns";

// report_timesheet serves 200 rows per call at most.
const PAGE_SIZE = 200;

/** Excel, CSV and PDF of the summary under the branch, range and search the screen is showing. */
export const useTimesheetExport = (filter: Ref<TimesheetFilter>, enabled: Ref<boolean>, branchName: () => string | undefined) =>
  useTableExport({
    name: "Bảng công",
    permission: "attendance",
    columns: timesheetExportColumns,
    pageSize: PAGE_SIZE,
    enabled: () => enabled.value,
    fetchPage: (pageIndex, pageSize) => getTimesheet(supabaseClient(), filter.value, pageSize, (pageIndex - 1) * pageSize),
    meta: () => [branchName() ? `Cơ sở: ${branchName()}` : "Tất cả cơ sở", `Từ ${filter.value.from} đến ${filter.value.to}`],
  });
