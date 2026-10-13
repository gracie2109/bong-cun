import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { cancelMyShopOrder, getMyShopOrder, listMyShopOrders, placeShopOrder } from "@/repositories/shop";
import type { PlaceOrderInput, ShopOrderStatus } from "@/types/shopOrder";
import { isOpenOrder } from "@/utils/shop/order";
import { shopKeys } from "./keys";
import { notifyFailure } from "./notify";

const ORDER_REFRESH_MS = 20_000;

/** The shopper's orders, newest first; `status` null lists all of them. */
export const useMyShopOrders = (
  status: MaybeRef<ShopOrderStatus | null>,
  page: MaybeRef<number>,
  pageSize: MaybeRef<number>
) =>
  useQuery({
    queryKey: computed(() => shopKeys.orderList(unref(status), unref(page), unref(pageSize))),
    queryFn: () => listMyShopOrders(supabaseClient(), { status: unref(status), page: unref(page), pageSize: unref(pageSize) }),
    placeholderData: keepPreviousData,
  });

/** One order of the shopper. While it can still change it is read again every 20 seconds. */
export const useMyShopOrder = (code: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => shopKeys.order(unref(code))),
    queryFn: () => getMyShopOrder(supabaseClient(), unref(code)),
    refetchInterval: (query) => (query.state.data && isOpenOrder(query.state.data.status) ? ORDER_REFRESH_MS : false),
    retry: false,
  });

/** Failures are explained by the checkout itself (it knows which field to point at). */
export const usePlaceShopOrder = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: PlaceOrderInput) => placeShopOrder(supabaseClient(), input),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: shopKeys.orders() });
      // Stock held for the order changes what the cart can still buy.
      await queryClient.invalidateQueries({ queryKey: [...shopKeys.all, "cart"] });
    },
  });
};

export const useCancelShopOrder = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { code: string; reason: string }) => cancelMyShopOrder(supabaseClient(), input.code, input.reason),
    onSuccess: async (order) => {
      queryClient.setQueryData(shopKeys.order(order.code), order);
      await queryClient.invalidateQueries({ queryKey: shopKeys.orders() });
    },
    onError: (error) => notifyFailure("update", error),
  });
};
