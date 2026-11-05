import { computed } from "vue";
import { buildStaffLines, summarize, useAttendanceToday } from "@/features/admin/attendance";
import { useWidgetAccess } from "../../kit/widgetScope";
import { resolveWidgetState, statusOf } from "../../kit/widgetState";
import { useToday } from "../../useToday";

/** Who is working, who has not clocked in and who is on leave at the branch today. */
export const useStaffToday = () => {
  const { allowed, needsBranch, branchId } = useWidgetAccess(["attendance"], ["branch"]);
  const today = useToday();
  const query = useAttendanceToday(branchId, today);

  const stats = computed(() => {
    const board = query.data.value;
    if (!board) return null;
    const sum = summarize(buildStaffLines(board));
    return [
      { key: "working", value: sum.working },
      { key: "notIn", value: sum.notIn },
      { key: "upcoming", value: sum.upcoming },
      { key: "leave", value: sum.leave },
    ] as const;
  });
  const state = computed(() =>
    resolveWidgetState({ allowed: allowed.value, needsBranch: needsBranch.value, query: statusOf(query), isEmpty: false })
  );
  return { state, stats, refetch: () => query.refetch() };
};
