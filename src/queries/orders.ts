import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabase } from "@/plugins/supabase";
import {
  createOrder,
  getOrderDetail,
  listOrders,
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
    queryFn: () => listOrders(supabase, toPage(unref(page)), { phoneNumber: unref(phoneNumber) }),
    placeholderData: keepPreviousData,
  });

export const useOrderDetail = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => orderKeys.detail(unref(id) ?? "")),
    queryFn: () => getOrderDetail(supabase, unref(id) as string),
    enabled: computed(() => !!unref(id)),
  });

export const useCreateOrder = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: CreateOrderInput) => createOrder(supabase, input),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: orderKeys.all });
      notifySuccess("create");
    },
    onError: (error) => notifyFailure("create", error),
  });
};
