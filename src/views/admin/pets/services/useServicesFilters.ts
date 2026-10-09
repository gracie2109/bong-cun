import { computed, ref } from "vue";
import { usePagedSearch } from "@/composables/usePagedSearch";
import { FILTER_ALL, SEARCH_DEBOUNCE_FAST_MS } from "@/lib/listing";
import { useSpeciesOptions } from "@/queries/species";
import type { PetServiceFilter } from "@/repositories/petServices";

const PAGE_SIZE = 10;

/** Filter, paging and species options of the services list page. */
export const useServicesFilters = () => {
  const speciesFilter = ref(FILTER_ALL);
  const typeFilter = ref(FILTER_ALL);
  const showArchived = ref(false);

  // Any filter change goes back to the first page.
  const { search, debouncedSearch, page: pageData } = usePagedSearch({
    pageSize: PAGE_SIZE,
    debounceMs: SEARCH_DEBOUNCE_FAST_MS,
    resetOn: [speciesFilter, typeFilter, showArchived],
  });

  const filter = computed<PetServiceFilter>(() => ({
    search: debouncedSearch.value,
    speciesId: speciesFilter.value === FILTER_ALL ? undefined : speciesFilter.value,
    type: typeFilter.value === FILTER_ALL ? undefined : (typeFilter.value as "all" | "by_weight"),
    includeArchived: showArchived.value,
  }));

  const speciesQuery = useSpeciesOptions();
  const species = computed(() => speciesQuery.data.value ?? []);

  return { search, speciesFilter, typeFilter, showArchived, pageData, filter, species };
};
