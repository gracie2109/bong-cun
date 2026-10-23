import { computed } from "vue";
import { useMedicalQueue, useMedicalReminders } from "@/features/admin/medical";
import { useWidgetAccess } from "../../kit/widgetScope";
import { resolveWidgetState, statusOf } from "../../kit/widgetState";
import { useToday } from "../../useToday";

const ONE_ROW = { pageIndex: 1, pageSize: 1 };
const OVERDUE = { scope: "overdue" } as const;

export const useMedicalToday = () => {
  const { allowed, needsBranch, branchId } = useWidgetAccess(["medical"], ["branch"]);
  const today = useToday();
  const queue = useMedicalQueue(branchId, today);
  const overdue = useMedicalReminders(branchId, ONE_ROW, OVERDUE);

  const stats = computed(() => {
    const counts = queue.data.value?.counts;
    if (!counts) return null;
    return [
      { key: "waiting", value: counts.waiting },
      { key: "inProgress", value: counts.inProgress },
      { key: "toPay", value: counts.done },
      { key: "overdue", value: overdue.data.value?.total ?? 0 },
    ] as const;
  });
  const state = computed(() =>
    resolveWidgetState({ allowed: allowed.value, needsBranch: needsBranch.value, query: statusOf(queue), isEmpty: false })
  );
  return { state, stats, refetch: () => queue.refetch() };
};
