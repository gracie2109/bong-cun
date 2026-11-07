import { computed, ref } from "vue";
import { todayInVietnam } from "@/lib/businessDate";
import { addDays, mondayOf } from "@bongcun/core/attendance";

/** The week being registered for: starts at next week (the running week is already past its deadline). */
export const useRegisterWeek = () => {
  const firstWeek = () => addDays(mondayOf(todayInVietnam()), 7);
  const monday = ref(firstWeek());
  const sunday = computed(() => addDays(monday.value, 6));
  const label = computed(
    () => `${monday.value.slice(8)}/${monday.value.slice(5, 7)} – ${sunday.value.slice(8)}/${sunday.value.slice(5, 7)}/${sunday.value.slice(0, 4)}`
  );
  return {
    monday,
    label,
    isFirstWeek: computed(() => monday.value === firstWeek()),
    previous: () => (monday.value = addDays(monday.value, -7)),
    next: () => (monday.value = addDays(monday.value, 7)),
    reset: () => (monday.value = firstWeek()),
  };
};
