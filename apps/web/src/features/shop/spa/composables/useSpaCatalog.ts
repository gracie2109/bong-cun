import { computed, ref, watch } from "vue";
import { useServerPrefetch } from "@/composables/shop/useServerPrefetch";
import { usePublicBranches } from "@/features/shared/public-api";
import { useSpaPublicCatalog } from "@/features/shop/spa/queries/spaCatalog";
import {
  combosForSpecies,
  servicesForSpecies,
  speciesWithOffers,
} from "@bongcun/core/spa";

/** The public price list: pick a branch (when there are several) and a species, read its services and combos. */
export const useSpaCatalog = () => {
  const branchesQuery = usePublicBranches();
  const branches = computed(() => branchesQuery.data.value ?? []);

  // Until a branch is picked the server answers for the first one, so both requests can run together
  // (a request that waits for another cannot be rendered on the server).
  const picked = ref<string | null>(null);
  const catalogQuery = useSpaPublicCatalog(picked);
  const catalog = computed(() => catalogQuery.data.value?.catalog ?? null);
  const branchId = computed(() => picked.value ?? catalogQuery.data.value?.branchId ?? branches.value[0]?.id ?? null);
  useServerPrefetch(branchesQuery, catalogQuery);

  const speciesList = computed(() => (catalog.value ? speciesWithOffers(catalog.value) : []));
  const speciesPicked = ref<string | null>(null);
  const species = computed(
    () => speciesList.value.find((item) => item.id === speciesPicked.value) ?? speciesList.value[0] ?? null
  );

  // Keep the pick valid when the list changes (another branch, data reloaded).
  watch(speciesList, (list) => {
    if (speciesPicked.value && !list.some((item) => item.id === speciesPicked.value)) speciesPicked.value = null;
  });

  const services = computed(() =>
    catalog.value && species.value ? servicesForSpecies(catalog.value, species.value.id) : []
  );
  const combos = computed(() =>
    catalog.value && species.value ? combosForSpecies(catalog.value, species.value.id) : []
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
