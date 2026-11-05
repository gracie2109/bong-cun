import { computed } from "vue";
import { useMySchedule } from "@/features/admin/attendance";
import { useWidgetAccess } from "../../kit/widgetScope";
import { resolveWidgetState, statusOf } from "../../kit/widgetState";
import { useToday } from "../../useToday";

/** My shifts of today across the branches I work at. */
export const useMyShifts = () => {
  const { allowed, needsBranch } = useWidgetAccess([], ["branch"]);
  const today = useToday();
  const query = useMySchedule(today, today);

  const shifts = computed(() => (query.data.value?.assignments ?? []).filter((shift) => shift.workDate === today.value));
  const state = computed(() =>
    resolveWidgetState({
      allowed: allowed.value,
      needsBranch: needsBranch.value,
      query: statusOf(query),
      isEmpty: !!query.data.value && shifts.value.length === 0,
    })
  );
  return { state, shifts, refetch: () => query.refetch() };
};
