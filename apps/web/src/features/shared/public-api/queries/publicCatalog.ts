import { keepPreviousData, useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import type { PageParams } from "@bongcun/supabase/shared";
import { shopCatalogKeys, shopKeys } from "@/queries/keys";
import { usePublicApi } from "../composables/usePublicApi";

// Lookups the public pages share. The staff screens keep their own queries (they need hidden rows too).

export const usePublicBranches = () => {
  const api = usePublicApi();
  return useQuery({ queryKey: shopCatalogKeys.branches(), queryFn: () => api.branches(), staleTime: 5 * 60 * 1000 });
};

export const usePublicCategories = (page: MaybeRef<PageParams>, rootsOnly = false) => {
  const api = usePublicApi();
  return useQuery({
    queryKey: computed(() => shopCatalogKeys.categories(unref(page), rootsOnly)),
    queryFn: () => api.categories(unref(page), rootsOnly),
    placeholderData: keepPreviousData,
  });
};

export const usePublicBrands = (page: MaybeRef<PageParams>) => {
  const api = usePublicApi();
  return useQuery({
    queryKey: computed(() => shopCatalogKeys.brands(unref(page))),
    queryFn: () => api.brands(unref(page)),
    placeholderData: keepPreviousData,
  });
};

/** One product group with only its sellable variants (null when it does not exist), plus its stock. */
export const usePublicGroup = (id: MaybeRef<string | undefined>) => {
  const api = usePublicApi();
  return useQuery({
    queryKey: computed(() => shopCatalogKeys.group(unref(id) ?? "")),
    queryFn: () => api.product(unref(id) ?? ""),
    enabled: computed(() => Boolean(unref(id))),
  });
};

/** What the product page, cart and checkout read about delivery; safe for anonymous visitors. */
export const useShopPublicSettings = () => {
  const api = usePublicApi();
  return useQuery({
    queryKey: shopKeys.publicSettings(),
    queryFn: () => api.shopSettings(),
    staleTime: 5 * 60 * 1000,
  });
};
