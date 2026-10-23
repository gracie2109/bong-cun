import { computed } from "vue";
import { useDayBoard } from "@/features/admin/schedule";
import { useWidgetAccess } from "../../kit/widgetScope";
import { resolveWidgetState, statusOf } from "../../kit/widgetState";
import { useToday } from "../../useToday";
import { countTickets, upcomingTickets } from "./spaStats";

export const useSpaToday = () => {
  const { allowed, needsBranch, branchId } = useWidgetAccess(["schedule"], ["branch"]);
  const today = useToday();
  const query = useDayBoard(branchId, today);

  const board = computed(() => query.data.value);
  const counts = computed(() => countTickets(board.value?.tickets ?? []));
  const upcoming = computed(() => upcomingTickets(board.value?.tickets ?? [], new Date().toISOString()));
  const state = computed(() =>
    resolveWidgetState({
      allowed: allowed.value,
      needsBranch: needsBranch.value,
      query: statusOf(query),
      isEmpty: !!board.value && (board.value.isClosed || board.value.tickets.length === 0),
    })
  );
  return { state, board, counts, upcoming, refetch: () => query.refetch() };
};
