import { computed, ref } from "vue";
import { usePagedList } from "@/composables/usePagedList";
import { useListFilters } from "@/composables/useListFilters";
import { useShopOrderList } from "@/queries/shopOrdersAdmin";
import type { OrderListFilter, OrderTab } from "@/types/shopOrderAdmin";

const PAGE_SIZE = 20;

/** The order list of the staff screen: tab, search (debounced), paging and the order that is open. */
export const useOrdersPage = () => {
  const tab = ref<OrderTab>("pending");
  // The tabs sit next to the search box and apply at once; there are no popover filters.
  const list = useListFilters({
    pageSize: PAGE_SIZE,
    defaults: {},
    quick: { tab: { value: tab, default: "pending" } },
  });
  const { debouncedSearch, page } = list;
  const filter = computed<OrderListFilter>(() => ({ tab: tab.value, search: debouncedSearch.value }));

  const query = useShopOrderList(page, filter);
  const { rows, total, pageCount } = usePagedList(query, page);
  const counts = computed(() => query.data.value?.counts ?? {});

  const openId = ref<string>();

  return { ...list, tab, query, rows, total, pageCount, counts, openId, filter };
};
