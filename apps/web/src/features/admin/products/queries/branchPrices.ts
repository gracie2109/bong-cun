import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  getBranchPrices,
  listPriceEditableBranchIds,
  listProductBranchPrices,
  setProductBranchPrices,
  type BranchPriceChange,
} from "@bongcun/supabase/spa";
import { branchPriceKeys, productKeys } from "@/queries/keys";
import { notifyFailure } from "@/queries/notify";

/** The branch prices of some products at one branch, for the POS to lay over the catalogue. */
export const useBranchPrices = (branchId: MaybeRef<string | undefined>, productIds: MaybeRef<string[]>) =>
  useQuery({
    queryKey: computed(() => branchPriceKeys.at(unref(branchId) ?? "", unref(productIds))),
    queryFn: () => getBranchPrices(supabaseClient(), unref(branchId) as string, unref(productIds)),
    enabled: computed(() => !!unref(branchId) && unref(productIds).length > 0),
    placeholderData: keepPreviousData,
  });

/** Every branch's price for some products, for the price grid on the product sheet. */
export const useProductBranchPrices = (productIds: MaybeRef<string[]>, enabled: MaybeRef<boolean> = true) =>
  useQuery({
    queryKey: computed(() => branchPriceKeys.byProduct(unref(productIds))),
    queryFn: () => listProductBranchPrices(supabaseClient(), unref(productIds)),
    enabled: computed(() => unref(enabled) && unref(productIds).length > 0),
  });

/** Branches where the signed-in staff member may set a price. */
export const usePriceEditableBranchIds = (enabled: MaybeRef<boolean> = true) =>
  useQuery({
    queryKey: [...branchPriceKeys.all, "editable"] as const,
    queryFn: () => listPriceEditableBranchIds(supabaseClient()),
    enabled: computed(() => unref(enabled)),
  });

export type ProductPriceChanges = { productId: string; changes: BranchPriceChange[] };

/** Saves only the cells that changed; the group's own save has already shown the success toast. */
export const useSaveBranchPrices = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (list: ProductPriceChanges[]) => {
      for (const { productId, changes } of list) await setProductBranchPrices(supabaseClient(), productId, changes);
    },
    onSuccess: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: branchPriceKeys.all }),
        queryClient.invalidateQueries({ queryKey: productKeys.all }),
      ]),
    onError: (error) => notifyFailure("update", error),
  });
};
