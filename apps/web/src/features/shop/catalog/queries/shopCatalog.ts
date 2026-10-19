import { keepPreviousData, useInfiniteQuery, useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import type { CatalogFilters } from "@bongcun/core/shop";
import { shopCatalogKeys } from "@/queries/keys";
import { usePublicApi } from "@/features/shared/public-api";

/** Groups per request of the shop list; "Xem thêm" fetches the next page. */
export const SHOP_PAGE_SIZE = 24;

/** The shop list a page at a time, narrowed by the filters (search is already debounced by the caller). */
export const useShopCatalog = (filters: MaybeRef<Partial<CatalogFilters>>, pageSize = SHOP_PAGE_SIZE) => {
  const api = usePublicApi();
  const query = useInfiniteQuery({
    queryKey: computed(() => shopCatalogKeys.list({ ...unref(filters) }, pageSize)),
    queryFn: ({ pageParam }) => api.products({ pageIndex: pageParam, pageSize }, { ...unref(filters) }),
    initialPageParam: 1,
    getNextPageParam: (last, all) => {
      const loaded = all.reduce((sum, page) => sum + page.rows.length, 0);
      return loaded < last.total ? all.length + 1 : undefined;
    },
    placeholderData: keepPreviousData,
  });

  const groups = computed(() => query.data.value?.pages.flatMap((page) => page.rows) ?? []);
  const total = computed(() => query.data.value?.pages[0]?.total ?? 0);
  const loadMore = () => {
    if (query.hasNextPage.value && !query.isFetchingNextPage.value) void query.fetchNextPage();
  };

  return { groups, total, loadMore, query };
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
