import { computed } from "vue";
import { useLocalStorage } from "@vueuse/core";
import { useBoardingBoard } from "@/features/admin/boarding";
import { useWidgetAccess } from "../../kit/widgetScope";
import { resolveWidgetState, statusOf } from "../../kit/widgetState";
import { useToday } from "../../useToday";
import { petCounts } from "./boardingStats";

export type BoardingUnit = "kennels" | "pets";

export const useBoardingToday = () => {
  const { allowed, needsBranch, branchId } = useWidgetAccess(["boarding"], ["branch"]);
  const today = useToday();
  const query = useBoardingBoard(branchId, today);
  const unit = useLocalStorage<BoardingUnit>("admin.dashboard.boardingUnit", "kennels");

  const counts = computed(() => {
    const board = query.data.value;
    if (!board) return null;
    return unit.value === "pets" ? petCounts(board) : board.counts;
  });
  const state = computed(() =>
    resolveWidgetState({ allowed: allowed.value, needsBranch: needsBranch.value, query: statusOf(query), isEmpty: false })
  );
  return { state, counts, unit, refetch: () => query.refetch() };
};
