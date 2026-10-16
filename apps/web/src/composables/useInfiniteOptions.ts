import { keepPreviousData, useInfiniteQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import type { Page, PageParams } from "@/repositories/shared";

/** Rows fetched per request by a select or picker that loads more as it scrolls. */
export const OPTIONS_PAGE_SIZE = 20;

type Options<T> = {
  /** The query key for one search text; the page size is added to it. */
  queryKey: (search: string) => readonly unknown[];
  /** One page of rows matching the search text, with the total of all pages. */
  fetchPage: (page: PageParams, search: string) => Promise<Page<T>>;
  search: MaybeRef<string>;
  pageSize?: number;
  enabled?: MaybeRef<boolean>;
};

/** A searchable list read a page at a time: `loadMore` fetches the next page until `hasMore` is false. */
export const useInfiniteOptions = <T>({ queryKey, fetchPage, search, pageSize = OPTIONS_PAGE_SIZE, enabled }: Options<T>) => {
  const query = useInfiniteQuery({
    queryKey: computed(() => [...queryKey(unref(search).trim()), pageSize]),
    queryFn: ({ pageParam }) => fetchPage({ pageIndex: pageParam, pageSize }, unref(search).trim()),
    initialPageParam: 1,
    getNextPageParam: (last, all) => {
      const loaded = all.reduce((sum, page) => sum + page.rows.length, 0);
      return loaded < last.total ? all.length + 1 : undefined;
    },
    placeholderData: keepPreviousData,
    enabled,
  });

  const items = computed(() => query.data.value?.pages.flatMap((page) => page.rows) ?? []);
  const loadMore = () => {
    if (query.hasNextPage.value && !query.isFetchingNextPage.value) void query.fetchNextPage();
  };

  return {
    items,
    loadMore,
    hasMore: query.hasNextPage,
    loading: query.isFetching,
    loadingMore: query.isFetchingNextPage,
    query,
  };
};
