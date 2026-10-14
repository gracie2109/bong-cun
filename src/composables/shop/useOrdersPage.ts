import { computed, ref } from "vue";
import { usePagedList } from "@/composables/usePagedList";
import { usePagedSearch } from "@/composables/usePagedSearch";
import { useShopOrderList } from "@/queries/shopOrdersAdmin";
import type { OrderListFilter, OrderTab } from "@/types/shopOrderAdmin";

const PAGE_SIZE = 20;

/** The order list of the staff screen: tab, search (debounced), paging and the order that is open. */
export const useOrdersPage = () => {
  const tab = ref<OrderTab>("pending");
  const { search, debouncedSearch, page } = usePagedSearch({ pageSize: PAGE_SIZE, resetOn: [tab] });
  const filter = computed<OrderListFilter>(() => ({ tab: tab.value, search: debouncedSearch.value }));

  const query = useShopOrderList(page, filter);
  const { rows, total, pageCount } = usePagedList(query, page);
  const counts = computed(() => query.data.value?.counts ?? {});

  const openId = ref<string>();

  return { tab, search, page, query, rows, total, pageCount, counts, openId, filter };
};
