import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { listMedicalReminders } from "@bongcun/supabase/medical";
import type { ReminderFilter } from "@bongcun/core/medical";
import { remindersExportColumns } from "./remindersExportColumns";

// medical_reminders serves 100 rows per page at most.
const PAGE_SIZE = 100;

/** Export of the call list under the tab and search the screen is showing. */
export const useRemindersExport = (branchId: Ref<string | undefined>, filter: Ref<ReminderFilter>, branchName: () => string | undefined) =>
  useTableExport({
    name: "Nhắc lịch",
    permission: "medical",
    columns: remindersExportColumns,
    pageSize: PAGE_SIZE,
    enabled: () => !!branchId.value,
    fetchPage: (pageIndex, pageSize) => {
      if (!branchId.value) return Promise.resolve({ rows: [], total: 0 });
      return listMedicalReminders(supabaseClient(), branchId.value, { pageIndex, pageSize }, filter.value);
    },
    meta: () => (branchName() ? [`Cơ sở: ${branchName()}`] : []),
  });
