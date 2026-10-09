import { computed, ref, watch } from "vue";
import { usePagedSearch } from "@/composables/usePagedSearch";
import { FILTER_ALL, SEARCH_DEBOUNCE_FAST_MS } from "@/lib/listing";
import { useSpeciesOptions } from "@/queries/species";
import { useWeightBrackets } from "@/queries/weightBrackets";
import type { PetListFilter, PetStatus } from "@/repositories/pets";

export const PET_STATUSES: PetStatus[] = ["active", "archived", "deceased"];

const PAGE_SIZE = 10;

/** Filter, paging and option lists of the pets list page. */
export const usePetsFilters = () => {
  const speciesFilter = ref(FILTER_ALL);
  const bracketFilter = ref(FILTER_ALL);
  const statusFilter = ref<PetStatus>("active");

  // Any filter change goes back to the first page.
  const { search, debouncedSearch, page: pageData } = usePagedSearch({
    pageSize: PAGE_SIZE,
    debounceMs: SEARCH_DEBOUNCE_FAST_MS,
    resetOn: [speciesFilter, bracketFilter, statusFilter],
  });

  const filter = computed<PetListFilter>(() => ({
    search: debouncedSearch.value,
    speciesId: speciesFilter.value === FILTER_ALL ? undefined : speciesFilter.value,
    bracketId: bracketFilter.value === FILTER_ALL ? undefined : bracketFilter.value,
    status: statusFilter.value,
  }));

  const speciesQuery = useSpeciesOptions();
  const species = computed(() => speciesQuery.data.value ?? []);

  const bracketSpeciesId = computed(() =>
    speciesFilter.value === FILTER_ALL ? undefined : speciesFilter.value
  );
  const bracketsQuery = useWeightBrackets(bracketSpeciesId, {
    enabled: computed(() => bracketSpeciesId.value !== undefined),
  });
  const brackets = computed(() => bracketsQuery.data.value ?? []);

  // A bracket of another species no longer applies.
  watch(speciesFilter, () => {
    bracketFilter.value = FILTER_ALL;
  });

  return {
    search,
    speciesFilter,
    bracketFilter,
    statusFilter,
    pageData,
    filter,
    species,
    brackets,
  };
};
