import { useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getCommunes, getLocation, getLocationCatalog, getProvinces } from "@bongcun/supabase/locations";
import { locationKeys } from "./locationKeys";

const ONE_HOUR = 60 * 60 * 1000;
const NO_CATALOG = "none";

/** The cache's current catalog; null while the first sync has not run. */
export const useLocationCatalog = () =>
  useQuery({ queryKey: locationKeys.catalog(), queryFn: () => getLocationCatalog(supabaseClient()), staleTime: ONE_HOUR });

const useCatalogId = () => {
  const catalog = useLocationCatalog();
  return { catalogId: computed(() => catalog.data.value?.id ?? NO_CATALOG), ready: computed(() => catalog.isSuccess.value) };
};

/** The lists only change with a sync, which changes the catalog id, so they stay fresh for the visit. */
export const useProvinces = () => {
  const { catalogId, ready } = useCatalogId();
  return useQuery({
    queryKey: computed(() => locationKeys.provinces(catalogId.value)),
    queryFn: () => getProvinces(supabaseClient()),
    enabled: ready,
    staleTime: Infinity,
  });
};

export const useCommunes = (provinceCode: MaybeRef<string | null>) => {
  const { catalogId, ready } = useCatalogId();
  return useQuery({
    queryKey: computed(() => locationKeys.communes(catalogId.value, unref(provinceCode) ?? "")),
    queryFn: async () => (await getCommunes(supabaseClient(), unref(provinceCode) as string)).items,
    enabled: computed(() => ready.value && !!unref(provinceCode)),
    staleTime: Infinity,
  });
};

/** One unit by code, to show a saved choice by its names. */
export const useLocationUnit = (code: MaybeRef<string | null>) => {
  const { catalogId, ready } = useCatalogId();
  return useQuery({
    queryKey: computed(() => locationKeys.unit(catalogId.value, unref(code) ?? "")),
    queryFn: () => getLocation(supabaseClient(), unref(code) as string),
    enabled: computed(() => ready.value && !!unref(code)),
    staleTime: Infinity,
  });
};
