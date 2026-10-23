import { computed } from "vue";
import { useShopOrderList } from "@/features/admin/shop-orders";
import { useWidgetAccess } from "../../kit/widgetScope";
import { resolveWidgetState, statusOf } from "../../kit/widgetState";
import { noOpenOrders } from "./onlineOrders";

const PAGE = { pageIndex: 1, pageSize: 1 };
const FILTER = { tab: "all", search: "" } as const;

/** Online orders by status: only the counts are read (a page of one row). Orders belong to the online branch. */
export const useOnlineOrders = () => {
  const { allowed, needsBranch } = useWidgetAccess(["shop_orders"], ["branch", "all"]);
  const query = useShopOrderList(PAGE, FILTER, allowed);
  const counts = computed(() => query.data.value?.counts);
  const state = computed(() =>
    resolveWidgetState({
      allowed: allowed.value,
      needsBranch: needsBranch.value,
      query: statusOf(query),
      isEmpty: !!query.data.value && noOpenOrders(counts.value),
    })
  );
  return { state, counts, refetch: () => query.refetch() };
};
