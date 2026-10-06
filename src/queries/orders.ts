import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  createOrder,
  getOrderDetail,
  listOrders,
  listOrdersByUserIds,
  type CreateOrderInput,
} from "@/repositories/orders";
import { toPage, type PageParams } from "@/repositories/shared";
import { orderKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

export const useOrdersList = (
  page: MaybeRef<PageParams>,
  phoneNumber?: MaybeRef<string | undefined>
) =>
  useQuery({
    queryKey: computed(() => orderKeys.list(toPage(unref(page)), unref(phoneNumber))),
    queryFn: () => listOrders(supabaseClient(), toPage(unref(page)), { phoneNumber: unref(phoneNumber) }),
    placeholderData: keepPreviousData,
  });

export const useOrderDetail = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => orderKeys.detail(unref(id) ?? "")),
    queryFn: () => getOrderDetail(supabaseClient(), unref(id) as string),
    enabled: computed(() => !!unref(id)),
  });

export const useOrdersByUsers = (userIds: MaybeRef<string[]>) =>
  useQuery({
    queryKey: computed(() => orderKeys.byUsers(unref(userIds))),
    queryFn: () => listOrdersByUserIds(supabaseClient(), unref(userIds)),
    enabled: computed(() => unref(userIds).length > 0),
    placeholderData: keepPreviousData,
  });

export const useCreateOrder = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: CreateOrderInput) => createOrder(supabaseClient(), input),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: orderKeys.all });
      notifySuccess("create");
    },
    onError: (error) => notifyFailure("create", error),
  });
};
