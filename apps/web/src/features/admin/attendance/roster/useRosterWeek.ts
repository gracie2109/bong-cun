import { computed, ref } from "vue";
import { todayInVietnam } from "@/lib/businessDate";
import { addDays, mondayOf, weekDays } from "@bongcun/core/attendance";

/** Which week the roster shows: the Monday of it, and the moves between weeks. */
export const useRosterWeek = () => {
  const monday = ref(mondayOf(todayInVietnam()));
  const days = computed(() => weekDays(monday.value));
  const sunday = computed(() => addDays(monday.value, 6));
  const isThisWeek = computed(() => monday.value === mondayOf(todayInVietnam()));

  /** The whole week is behind us, so nothing in it can change any more. */
  const isPastWeek = computed(() => sunday.value < todayInVietnam());

  return {
    monday,
    days,
    sunday,
    isThisWeek,
    isPastWeek,
    previous: () => (monday.value = addDays(monday.value, -7)),
    next: () => (monday.value = addDays(monday.value, 7)),
    select: (value: string) => (monday.value = mondayOf(value)),
    today: () => (monday.value = mondayOf(todayInVietnam())),
  };
};
