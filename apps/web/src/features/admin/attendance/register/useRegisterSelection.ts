import { computed, ref, watch, type Ref } from "vue";
import { cellKey, splitCellKey } from "./registerGrid";

const MAX_CELLS = 21;

/** The ticked cells of the grid. Clears itself when the branch or the week changes. */
export const useRegisterSelection = (scope: Ref<string>) => {
  const keys = ref<string[]>([]);
  watch(scope, () => (keys.value = []));

  const has = (date: string, templateId: string) => keys.value.includes(cellKey(date, templateId));
  const toggle = (date: string, templateId: string) => {
    const key = cellKey(date, templateId);
    if (keys.value.includes(key)) keys.value = keys.value.filter((k) => k !== key);
    else if (keys.value.length < MAX_CELLS) keys.value = [...keys.value, key];
  };
  const clear = () => (keys.value = []);
  const cells = computed(() => keys.value.map(splitCellKey));

  return { keys, count: computed(() => keys.value.length), cells, has, toggle, clear, max: MAX_CELLS };
};
