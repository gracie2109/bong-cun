import { computed, ref, type Ref } from "vue";
import { useIntervalFn } from "@vueuse/core";

/** Whole minutes since `since`, kept fresh every 30 seconds. */
export const useElapsedMinutes = (since: Ref<string | null | undefined>) => {
  const now = ref(Date.now());
  useIntervalFn(() => (now.value = Date.now()), 30_000);
  return computed(() => (since.value ? Math.max(0, Math.floor((now.value - new Date(since.value).getTime()) / 60_000)) : 0));
};
