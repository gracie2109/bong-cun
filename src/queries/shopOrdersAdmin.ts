import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getShopOrder, listShopOrders, runOrderStep, type OrderStepCall } from "@/repositories/shop";
import type { PageParams } from "@/repositories/shared";
import type { OrderListFilter } from "@/types/shopOrderAdmin";
import { shopKeys } from "./keys";

const FAST_REFRESH_MS = 30_000;

/** One page of online orders. Read again every 30 seconds so new orders show up. */
export const useShopOrderList = (page: MaybeRef<PageParams>, filter: MaybeRef<OrderListFilter>) =>
  useQuery({
    queryKey: computed(() => shopKeys.staffOrderList({ ...unref(page) }, { ...unref(filter) })),
    queryFn: () => listShopOrders(supabaseClient(), { ...unref(page) }, { ...unref(filter) }),
    placeholderData: keepPreviousData,
    refetchInterval: FAST_REFRESH_MS,
  });

export const useShopOrderDetail = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => shopKeys.staffOrder(unref(id) ?? "")),
    queryFn: () => getShopOrder(supabaseClient(), unref(id) as string),
    enabled: computed(() => !!unref(id)),
  });

/**
 * A step of an order (confirm, pack, ship, deliver, return, cancel). The order it returns replaces
 * the open detail and the lists are read again. Failures are shown by the caller, which knows the
 * dialog the message belongs to.
 */
export const useOrderStep = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (call: OrderStepCall) => runOrderStep(supabaseClient(), call),
    onSuccess: async (order) => {
      queryClient.setQueryData(shopKeys.staffOrder(order.id), order);
      await queryClient.invalidateQueries({ queryKey: shopKeys.staffOrders() });
      // The stock a packed or cancelled order took or gave back changes what can be sold.
      await queryClient.invalidateQueries({ queryKey: [...shopKeys.all, "cart"] });
    },
  });
};
