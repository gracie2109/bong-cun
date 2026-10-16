import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { listShopOrders } from "@/repositories/shop/ordersAdmin";
import type { OrderListFilter } from "@bongcun/core/shop";
import { ordersExportColumns } from "./ordersExportColumns";

// list_shop_orders serves 100 rows per page at most.
const PAGE_SIZE = 100;

/** Export of the online orders under the tab and search the list is showing. */
export const useOrdersExport = (filter: Ref<OrderListFilter>) =>
  useTableExport({
    name: "Đơn online",
    permission: "shop_orders",
    columns: ordersExportColumns,
    pageSize: PAGE_SIZE,
    fetchPage: (pageIndex, pageSize) => listShopOrders(supabaseClient(), { pageIndex, pageSize }, filter.value),
    meta: () => (filter.value.search ? [`Tìm: ${filter.value.search}`] : []),
  });
