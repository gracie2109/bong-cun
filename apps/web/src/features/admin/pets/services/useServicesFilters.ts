import { computed } from "vue";
import { useListFilters } from "@/composables/useListFilters";
import { FILTER_ALL, SEARCH_DEBOUNCE_FAST_MS } from "@/lib/listing";
import { useSpeciesOptions } from "@/features/admin/pets/queries/species";
import type { PetServiceFilter } from "@bongcun/supabase/spa";
import type { ServiceCategory } from "@bongcun/core/medical";

const PAGE_SIZE = 10;

/** Filter, paging and species options of the services list page. */
export const useServicesFilters = () => {
  const list = useListFilters({
    pageSize: PAGE_SIZE,
    debounceMs: SEARCH_DEBOUNCE_FAST_MS,
    defaults: { speciesId: FILTER_ALL as string, type: FILTER_ALL as string, category: FILTER_ALL as string, showArchived: false },
  });
  const { applied, debouncedSearch } = list;

  const filter = computed<PetServiceFilter>(() => ({
    search: debouncedSearch.value,
    speciesId: applied.value.speciesId === FILTER_ALL ? undefined : applied.value.speciesId,
    type: applied.value.type === FILTER_ALL ? undefined : (applied.value.type as "all" | "by_weight"),
    category: applied.value.category === FILTER_ALL ? undefined : (applied.value.category as ServiceCategory),
    includeArchived: applied.value.showArchived,
  }));

  const speciesQuery = useSpeciesOptions();
  const species = computed(() => speciesQuery.data.value ?? []);

  return { ...list, pageData: list.page, filter, species };
};
