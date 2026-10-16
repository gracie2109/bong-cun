import { computed, ref, watch } from "vue";
import { useBranches } from "@/queries/branches";
import { useSpaPublicCatalog } from "@/queries/spaCatalog";
import {
  combosForSpecies,
  servicesForSpecies,
  speciesWithOffers,
} from "@bongcun/core/spa";

/** The public price list: pick a branch (when there are several) and a species, read its services and combos. */
export const useSpaCatalog = () => {
  const branchesQuery = useBranches();
  const branches = computed(() => branchesQuery.data.value ?? []);

  const picked = ref<string | null>(null);
  const branchId = computed(() => picked.value ?? branches.value[0]?.id ?? null);
  const catalogQuery = useSpaPublicCatalog(branchId);

  const speciesList = computed(() => (catalogQuery.data.value ? speciesWithOffers(catalogQuery.data.value) : []));
  const speciesPicked = ref<string | null>(null);
  const species = computed(
    () => speciesList.value.find((item) => item.id === speciesPicked.value) ?? speciesList.value[0] ?? null
  );

  // Keep the pick valid when the list changes (another branch, data reloaded).
  watch(speciesList, (list) => {
    if (speciesPicked.value && !list.some((item) => item.id === speciesPicked.value)) speciesPicked.value = null;
  });

  const services = computed(() =>
    catalogQuery.data.value && species.value ? servicesForSpecies(catalogQuery.data.value, species.value.id) : []
  );
  const combos = computed(() =>
    catalogQuery.data.value && species.value ? combosForSpecies(catalogQuery.data.value, species.value.id) : []
  );

  return {
    branches,
    branchId,
    pickBranch: (id: string) => (picked.value = id),
    speciesList,
    species,
    pickSpecies: (id: string) => (speciesPicked.value = id),
    services,
    combos,
    loading: computed(() => branchesQuery.isLoading.value || catalogQuery.isLoading.value),
    failed: computed(() => branchesQuery.isError.value || catalogQuery.isError.value),
    retry: () => {
      void branchesQuery.refetch();
      void catalogQuery.refetch();
    },
  };
};
