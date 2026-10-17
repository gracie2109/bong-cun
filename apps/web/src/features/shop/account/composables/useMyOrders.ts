import { computed, ref, watch } from "vue";
import { useMyShopOrders } from "@/features/shop/orders/queries/shopOrders";
import type { ShopOrderStatus } from "@bongcun/core/shop";

const PAGE_SIZE = 10;

/** The "Đơn của tôi" tab of the profile: a status filter and paging over the shopper's orders. */
export const useMyOrders = () => {
  /** null lists every order. */
  const status = ref<ShopOrderStatus | null>(null);
  const page = ref(1);
  watch(status, () => (page.value = 1));

  const query = useMyShopOrders(status, page, PAGE_SIZE);
  const rows = computed(() => query.data.value?.rows ?? []);
  const total = computed(() => query.data.value?.totalCount ?? 0);
  const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));

  return { status, page, rows, total, pageCount, loading: query.isLoading, fetching: query.isFetching, failed: query.isError, retry: () => query.refetch() };
};
