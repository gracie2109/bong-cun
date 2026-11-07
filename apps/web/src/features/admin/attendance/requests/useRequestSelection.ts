import { computed, ref, watch, type Ref } from "vue";
import type { ShiftRequest } from "@bongcun/core/attendance";

/** Pending requests ticked in the list. A request that can no longer be decided cannot be ticked. */
export const canTick = (request: ShiftRequest) => request.status === "pending";

export const useRequestSelection = (rows: Ref<ShiftRequest[]>, resetOn: Ref<unknown>) => {
  const ids = ref<string[]>([]);
  watch([resetOn, rows], () => {
    const still = new Set(rows.value.filter(canTick).map((row) => row.id));
    ids.value = ids.value.filter((id) => still.has(id));
  });

  const has = (id: string) => ids.value.includes(id);
  const toggle = (id: string) => (ids.value = has(id) ? ids.value.filter((item) => item !== id) : [...ids.value, id]);
  const tickable = computed(() => rows.value.filter(canTick).map((row) => row.id));
  const allTicked = computed(() => tickable.value.length > 0 && tickable.value.every(has));
  const toggleAll = () => (ids.value = allTicked.value ? [] : [...tickable.value]);
  const clear = () => (ids.value = []);
  /** Ticks every id of a group, or unticks them when all are ticked already. */
  const toggleMany = (many: string[]) => {
    const all = many.length > 0 && many.every(has);
    ids.value = all ? ids.value.filter((id) => !many.includes(id)) : [...new Set([...ids.value, ...many])];
  };

  return { ids, has, toggle, toggleMany, toggleAll, allTicked, clear, count: computed(() => ids.value.length), tickable };
};
