import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  listServicePrices,
  saveServicePrices,
  type ServicePrice,
  type ServicePriceInput,
} from "@/repositories/servicePrices";
import { servicePriceKeys } from "./keys";
import { invalidateCatalog } from "./invalidate";
import { notifyFailure, notifySuccess } from "./notify";

type PriceFilter = { speciesId?: string; serviceId?: string; branchId?: string | null };

export const useServicePrices = (filter: MaybeRef<PriceFilter>) =>
  useQuery({
    queryKey: computed(() =>
      servicePriceKeys.list(
        unref(filter).speciesId ?? "",
        unref(filter).serviceId ?? null,
        unref(filter).branchId ?? null
      )
    ),
    queryFn: () =>
      listServicePrices(supabaseClient(), {
        speciesId: unref(filter).speciesId as string,
        serviceId: unref(filter).serviceId,
        branchId: unref(filter).branchId ?? null,
      }),
    enabled: computed(() => !!unref(filter).speciesId),
  });

/** Prices by `serviceId:bracketId`, for looking a matrix cell up. */
export const priceByCell = (prices: ServicePrice[]): Map<string, number> =>
  new Map(prices.map((price) => [`${price.serviceId}:${price.bracketId}`, price.price]));

export const useSaveServicePrices = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (args: {
      speciesId: string;
      serviceId: string;
      branchId: string | null;
      rows: ServicePriceInput[];
    }) => saveServicePrices(supabaseClient(), args),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};
