import { computed } from "vue";
import { useRoute } from "vue-router";
import { todayInVietnam } from "@/lib/businessDate";
import { addDays } from "@bongcun/core/attendance";
import { useMySchedule as useScheduleQuery } from "@/features/admin/attendance/queries";

const UPCOMING_DAYS = 14;

/** My shifts for the next two weeks and my entries since the start of this month. */
export const useMyAttendance = () => {
  const today = todayInVietnam();
  const from = `${today.slice(0, 8)}01`;
  // A notification can open the page on a later week: `?week=<monday>`.
  const requested = String(useRoute().query.week ?? "");
  const focusMonday = /^\d{4}-\d{2}-\d{2}$/.test(requested) ? requested : null;
  const focusEnd = focusMonday ? addDays(focusMonday, 6) : null;
  const defaultTo = addDays(today, UPCOMING_DAYS);
  const to = focusEnd && focusEnd > defaultTo ? focusEnd : defaultTo;
  const query = useScheduleQuery(from, to);

  const upcoming = computed(() => (query.data.value?.assignments ?? []).filter((shift) => shift.workDate >= today));
  const entries = computed(() => [...(query.data.value?.entries ?? [])].sort((a, b) => b.checkInAt.localeCompare(a.checkInAt)));
  const leaves = computed(() => query.data.value?.leaves ?? []);

  return { today, focusMonday, query, upcoming, entries, leaves };
};
