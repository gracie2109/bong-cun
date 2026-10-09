import { computed, ref, watch } from "vue";
import { useSpeciesSummaries } from "@/queries/species";

/** The species list and which one is open: the first until another is picked, or when the open one is hidden. */
export const useSpeciesSelection = () => {
  const summariesQuery = useSpeciesSummaries();
  const showArchived = ref(false);
  const selectedId = ref<string>();

  const all = computed(() => summariesQuery.data.value ?? []);
  const visible = computed(() => all.value.filter((item) => showArchived.value || item.isActive));
  const selected = computed(() => all.value.find((item) => item.id === selectedId.value));

  watch(
    visible,
    (list) => {
      if (!list.some((item) => item.id === selectedId.value)) selectedId.value = list[0]?.id;
    },
    { immediate: true }
  );

  return { pending: summariesQuery.isPending, showArchived, selectedId, visible, selected };
};
