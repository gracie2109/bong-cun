import { computed, ref, type Ref } from "vue";

/** The product groups ticked in the list; the ticks stay while paging and filtering. */
export const useProductSelection = (pageIds: Ref<string[]>) => {
  const selected = ref(new Set<string>());

  const count = computed(() => selected.value.size);
  const ids = computed(() => [...selected.value]);
  const isSelected = (id: string) => selected.value.has(id);

  const allOnPage = computed(() => pageIds.value.length > 0 && pageIds.value.every((id) => selected.value.has(id)));
  const someOnPage = computed(() => pageIds.value.some((id) => selected.value.has(id)));

  const toggle = (id: string, on: boolean) => {
    const next = new Set(selected.value);
    if (on) next.add(id);
    else next.delete(id);
    selected.value = next;
  };

  const togglePage = (on: boolean) => {
    const next = new Set(selected.value);
    for (const id of pageIds.value) {
      if (on) next.add(id);
      else next.delete(id);
    }
    selected.value = next;
  };

  const clear = () => {
    selected.value = new Set();
  };

  const remove = (removed: string[]) => {
    const next = new Set(selected.value);
    for (const id of removed) next.delete(id);
    selected.value = next;
  };

  return { count, ids, isSelected, allOnPage, someOnPage, toggle, togglePage, clear, remove };
};
