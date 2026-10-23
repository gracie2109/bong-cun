import { computed, ref } from "vue";
import { useIntervalFn } from "@vueuse/core";
import { todayInVietnam } from "@/features/admin/reports";

const MINUTE_MS = 60_000;

/** Today's date on the clinic's clock; moves on at midnight even when the screen stays open overnight. */
export const useToday = () => {
  const now = ref(new Date());
  useIntervalFn(() => (now.value = new Date()), MINUTE_MS);
  return computed(() => todayInVietnam(now.value));
};
