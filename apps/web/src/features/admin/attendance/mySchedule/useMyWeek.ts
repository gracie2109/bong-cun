import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import { todayInVietnam } from "@/lib/businessDate";
import { useMySchedule } from "@/features/admin/attendance/queries";
import { addDays, mondayOf, weekDays } from "@bongcun/core/attendance";
import type { MyShift, RosterLeave } from "@bongcun/core/attendance";

export type MyDay = { date: string; shifts: MyShift[]; leave: RosterLeave | null };

/** My own week: the shifts the manager has published for me (the database hides drafts) and my approved leave. */
export const useMyWeek = () => {
  const today = todayInVietnam();
  // A link can open a given week: `?week=<date>`.
  const requested = String(useRoute().query.week ?? "");
  const monday = ref(mondayOf(/^\d{4}-\d{2}-\d{2}$/.test(requested) ? requested : today));
  const sunday = computed(() => addDays(monday.value, 6));
  const query = useMySchedule(monday, sunday);

  const days = computed<MyDay[]>(() =>
    weekDays(monday.value).map((date) => ({
      date,
      shifts: (query.data.value?.assignments ?? []).filter((shift) => shift.workDate === date).sort((a, b) => a.startAt.localeCompare(b.startAt)),
      leave: (query.data.value?.leaves ?? []).find((leave) => leave.fromDate <= date && date <= leave.toDate) ?? null,
    }))
  );
  const shiftCount = computed(() => days.value.reduce((sum, day) => sum + day.shifts.length, 0));
  const label = computed(() => `${monday.value.slice(8)}/${monday.value.slice(5, 7)} – ${sunday.value.slice(8)}/${sunday.value.slice(5, 7)}/${sunday.value.slice(0, 4)}`);

  return {
    today,
    monday,
    label,
    query,
    days,
    shiftCount,
    isThisWeek: computed(() => monday.value === mondayOf(today)),
    previous: () => (monday.value = addDays(monday.value, -7)),
    next: () => (monday.value = addDays(monday.value, 7)),
    select: (value: string) => (monday.value = mondayOf(value)),
    thisWeek: () => (monday.value = mondayOf(today)),
  };
};
