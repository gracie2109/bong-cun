import { computed } from "vue";
import { usePendingShiftRequestCount } from "@/features/admin/attendance";
import { useWidgetAccess } from "../../kit/widgetScope";
import { resolveWidgetState, statusOf } from "../../kit/widgetState";

/** Shift registration requests at the branch that wait for a manager's decision. */
export const useShiftRequestsWidget = () => {
  const { allowed, needsBranch, branchId } = useWidgetAccess(["attendance"], ["branch"]);
  const query = usePendingShiftRequestCount(allowed, branchId);
  const count = computed(() => query.data.value ?? 0);
  const state = computed(() =>
    resolveWidgetState({
      allowed: allowed.value,
      needsBranch: needsBranch.value,
      query: statusOf(query),
      isEmpty: query.data.value === 0,
    })
  );
  return { state, count, refetch: () => query.refetch() };
};
