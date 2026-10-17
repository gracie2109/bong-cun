import { computed } from "vue";
import { useListFilters } from "@/composables/useListFilters";
import { FILTER_ALL, SEARCH_DEBOUNCE_FAST_MS } from "@/lib/listing";
import { useSpeciesOptions } from "@/features/admin/pets/queries/species";
import { useWeightBrackets } from "@/features/admin/pets/queries/weightBrackets";
import type { PetListFilter, PetStatus } from "@bongcun/supabase/pets";

export const PET_STATUSES: PetStatus[] = ["active", "archived", "deceased"];

const PAGE_SIZE = 10;

/** Filter, paging and option lists of the pets list page. */
export const usePetsFilters = () => {
  const list = useListFilters({
    pageSize: PAGE_SIZE,
    debounceMs: SEARCH_DEBOUNCE_FAST_MS,
    defaults: { speciesId: FILTER_ALL as string, bracketId: FILTER_ALL as string, status: "active" as PetStatus },
  });
  const { applied, draft, debouncedSearch } = list;

  const filter = computed<PetListFilter>(() => ({
    search: debouncedSearch.value,
    speciesId: applied.value.speciesId === FILTER_ALL ? undefined : applied.value.speciesId,
    bracketId: applied.value.bracketId === FILTER_ALL ? undefined : applied.value.bracketId,
    status: applied.value.status,
  }));

  const speciesQuery = useSpeciesOptions();
  const species = computed(() => speciesQuery.data.value ?? []);

  // The bracket options follow the species being picked in the popover.
  const bracketSpeciesId = computed(() => (draft.speciesId === FILTER_ALL ? undefined : draft.speciesId));
  const bracketsQuery = useWeightBrackets(bracketSpeciesId, {
    enabled: computed(() => bracketSpeciesId.value !== undefined),
  });
  const brackets = computed(() => bracketsQuery.data.value ?? []);

  return { ...list, pageData: list.page, filter, species, brackets };
};
