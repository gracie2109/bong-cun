import { computed, ref, type Ref } from "vue";
import { useTimesheetGrid as useGridQuery } from "@/features/admin/attendance/queries";
import { todayInVietnam } from "@/lib/businessDate";
import { addMonths, monthStart } from "./timesheetRange";

/** The month grid of one branch: the month being shown and the steps back and forth. */
export const useMonthGrid = (branchId: Ref<string | undefined>) => {
  const month = ref(monthStart(todayInVietnam()));
  const query = useGridQuery(branchId, month);
  const grid = computed(() => query.data.value ?? null);

  const step = (count: number) => {
    month.value = addMonths(month.value, count);
  };
  const thisMonth = () => {
    month.value = monthStart(todayInVietnam());
  };

  return { month, query, grid, step, thisMonth };
};
