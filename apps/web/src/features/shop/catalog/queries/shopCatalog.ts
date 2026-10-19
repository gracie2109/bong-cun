import { useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import type { CatalogFilters } from "@bongcun/core/shop";
import { shopCatalogKeys } from "@/queries/keys";
import { usePublicApi } from "@/features/shared/public-api";

/** Groups per page of the shop list. */
export const SHOP_PAGE_SIZE = 24;

/** One page of the shop list, narrowed by the filters. Paging is by URL (?page=), so each page is rendered on the server. */
export const useShopCatalog = (filters: MaybeRef<Partial<CatalogFilters>>, pageSize = SHOP_PAGE_SIZE, page: MaybeRef<number> = 1) => {
  const api = usePublicApi();
  const query = useQuery({
    queryKey: computed(() => shopCatalogKeys.list({ ...unref(filters) }, pageSize, unref(page))),
    queryFn: () => api.products({ pageIndex: unref(page), pageSize }, { ...unref(filters) }),
  });

  const groups = computed(() => query.data.value?.rows ?? []);
  const total = computed(() => query.data.value?.total ?? 0);

  return { groups, total, query };
};

/** Other groups of the same category as `groupId`. */
export const useRelatedGroups = (groupId: MaybeRef<string | undefined>) => {
  const api = usePublicApi();
  return useQuery({
    queryKey: computed(() => shopCatalogKeys.related(unref(groupId) ?? "")),
    queryFn: () => api.related(unref(groupId) ?? ""),
    enabled: computed(() => Boolean(unref(groupId))),
  });
};
