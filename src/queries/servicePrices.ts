import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabase } from "@/plugins/supabase";
import {
  listServicePrices,
  saveServicePrices,
  type ServicePrice,
  type ServicePriceInput,
} from "@/repositories/servicePrices";
import { servicePriceKeys } from "./keys";
import { invalidateCatalog } from "./invalidate";
import { notifyFailure, notifySuccess } from "./notify";

type PriceFilter = { petId?: string; serviceId?: string };

export const useServicePrices = (filter: MaybeRef<PriceFilter>) =>
  useQuery({
    queryKey: computed(() => servicePriceKeys.list(unref(filter).petId ?? "", unref(filter).serviceId)),
    queryFn: () =>
      listServicePrices(supabase, {
        petId: unref(filter).petId as string,
        serviceId: unref(filter).serviceId,
      }),
    enabled: computed(() => !!unref(filter).petId),
  });

/** Groups a flat price list by service id (the shape the price table renders). */
export const groupPricesByService = (prices: ServicePrice[]): Record<string, ServicePrice[]> =>
  prices.reduce<Record<string, ServicePrice[]>>((groups, price) => {
    (groups[price.serviceId] ??= []).push(price);
    return groups;
  }, {});

export const useSaveServicePrices = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (args: { petId: string; serviceId: string; rows: ServicePriceInput[] }) =>
      saveServicePrices(supabase, args),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};
