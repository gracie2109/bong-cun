import { computed, ref, type Ref } from "vue";
import { todayInVietnam } from "@/lib/businessDate";
import { addDays } from "@bongcun/core/attendance";
import { useAttendanceToday as useTodayQuery } from "@/features/admin/attendance/queries";
import { buildStaffLines, summarize } from "./todayBoard";

/** The board of one day at one branch, with the moves between days. */
export const useTodayBoard = (branchId: Ref<string | undefined>) => {
  const date = ref(todayInVietnam());
  const query = useTodayQuery(branchId, date);
  const board = computed(() => query.data.value);
  const lines = computed(() => (board.value ? buildStaffLines(board.value) : []));
  const summary = computed(() => summarize(lines.value));
  const isToday = computed(() => date.value === todayInVietnam());

  return {
    date,
    query,
    board,
    lines,
    summary,
    isToday,
    previous: () => (date.value = addDays(date.value, -1)),
    next: () => (date.value = addDays(date.value, 1)),
    today: () => (date.value = todayInVietnam()),
  };
};
