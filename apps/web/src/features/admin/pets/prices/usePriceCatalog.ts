import { computed, ref, watch } from "vue";
import { useBranches } from "@/queries/branches";
import { useAllPetServices } from "@/queries/petServices";
import { priceByCell, useServicePrices } from "@/queries/servicePrices";
import { useSpeciesOptions } from "@/queries/species";
import { useWeightBrackets } from "@/queries/weightBrackets";

export const SHARED = "shared";

/** The species, scope (shared or one branch), weight brackets, by-weight services and prices on the grid. */
export const usePriceCatalog = (initialSpeciesId: string | undefined) => {
  const speciesQuery = useSpeciesOptions();
  const species = computed(() => speciesQuery.data.value ?? []);
  const speciesId = ref<string | undefined>(initialSpeciesId);
  // Default to the first species once the list is loaded.
  watch(
    species,
    (list) => {
      if (!list.some((item) => item.id === speciesId.value)) speciesId.value = list[0]?.id;
    },
    { immediate: true }
  );

  const branchesQuery = useBranches();
  const branches = computed(() => branchesQuery.data.value ?? []);
  const scope = ref(SHARED);
  const branchId = computed(() => (scope.value === SHARED ? null : scope.value));

  const bracketsQuery = useWeightBrackets(speciesId, { enabled: computed(() => !!speciesId.value) });
  const brackets = computed(() => bracketsQuery.data.value ?? []);

  const servicesQuery = useAllPetServices();
  const services = computed(() =>
    (servicesQuery.data.value ?? []).filter(
      (service) => service.type === "by_weight" && !!speciesId.value && service.speciesIds.includes(speciesId.value)
    )
  );

  const pricesQuery = useServicePrices(computed(() => ({ speciesId: speciesId.value, branchId: branchId.value })));
  const sharedQuery = useServicePrices(computed(() => ({ speciesId: speciesId.value, branchId: null })));
  const saved = computed(() => priceByCell(pricesQuery.data.value ?? []));
  const shared = computed(() => priceByCell(sharedQuery.data.value ?? []));

  // What a customer would actually pay at the current scope: override first, else the shared price.
  const effectivePrices = computed(() => new Map([...shared.value, ...saved.value]));

  return {
    speciesQuery,
    species,
    speciesId,
    branches,
    scope,
    branchId,
    bracketsQuery,
    brackets,
    servicesQuery,
    services,
    pricesQuery,
    saved,
    shared,
    effectivePrices,
  };
};
