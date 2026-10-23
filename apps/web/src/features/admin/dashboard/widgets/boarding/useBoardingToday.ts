import { computed } from "vue";
import { useBoardingBoard } from "@/features/admin/boarding";
import { useWidgetAccess } from "../../kit/widgetScope";
import { resolveWidgetState, statusOf } from "../../kit/widgetState";
import { useToday } from "../../useToday";

export const useBoardingToday = () => {
  const { allowed, needsBranch, branchId } = useWidgetAccess(["boarding"], ["branch"]);
  const today = useToday();
  const query = useBoardingBoard(branchId, today);
  const counts = computed(() => query.data.value?.counts ?? null);
  const state = computed(() =>
    resolveWidgetState({ allowed: allowed.value, needsBranch: needsBranch.value, query: statusOf(query), isEmpty: false })
  );
  return { state, counts, refetch: () => query.refetch() };
};
