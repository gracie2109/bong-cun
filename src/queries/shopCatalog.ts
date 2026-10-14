import { keepPreviousData, useInfiniteQuery, useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { listRelatedGroups, listShopGroups } from "@/repositories/shop";
import type { CatalogFilters } from "@/types/catalog";
import { shopCatalogKeys } from "./keys";

/** Groups per request of the shop list; "Xem thêm" fetches the next page. */
export const SHOP_PAGE_SIZE = 24;

/** The shop list a page at a time, narrowed by the filters (search is already debounced by the caller). */
export const useShopCatalog = (filters: MaybeRef<Partial<CatalogFilters>>, pageSize = SHOP_PAGE_SIZE) => {
  const query = useInfiniteQuery({
    queryKey: computed(() => shopCatalogKeys.list({ ...unref(filters) }, pageSize)),
    queryFn: ({ pageParam }) => listShopGroups(supabaseClient(), { pageIndex: pageParam, pageSize }, { ...unref(filters) }),
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
export const useRelatedGroups = (groupId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => shopCatalogKeys.related(unref(groupId) ?? "")),
    queryFn: () => listRelatedGroups(supabaseClient(), unref(groupId) ?? ""),
    enabled: computed(() => Boolean(unref(groupId))),
  });
