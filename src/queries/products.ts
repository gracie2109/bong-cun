import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  createProduct,
  listProducts,
  searchSellableProducts,
  setProductActive,
  updateProduct,
  type ProductFilter,
  type ProductInput,
} from "@/repositories/products";
import { toPage, type PageParams } from "@/repositories/shared";
import { inventoryKeys, productKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

export const useProductsList = (page: MaybeRef<PageParams>, filter: MaybeRef<ProductFilter> = {}) =>
  useQuery({
    queryKey: computed(() => productKeys.list(toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listProducts(supabaseClient(), toPage(unref(page)), { ...unref(filter) }),
    placeholderData: keepPreviousData,
  });

/** Active products matching the typed name, SKU or barcode (all of them while empty). */
export const useSellableProducts = (text: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => productKeys.sellable(unref(text).trim())),
    queryFn: () => searchSellableProducts(supabaseClient(), unref(text)),
    placeholderData: keepPreviousData,
  });

export const useSaveProduct = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id?: string; input: ProductInput }) =>
      id ? updateProduct(supabaseClient(), id, input) : createProduct(supabaseClient(), input),
    onSuccess: async (_data, { id }) => {
      // Stock tracking and archiving change what the stock screens list.
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: productKeys.all }),
        queryClient.invalidateQueries({ queryKey: inventoryKeys.all }),
      ]);
      notifySuccess(id ? "update" : "create");
    },
    onError: (error, { id, input }) => notifyFailure(id ? "update" : "create", error, input.name),
  });
};

export const useSetProductActive = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      setProductActive(supabaseClient(), id, isActive),
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: productKeys.all }),
        queryClient.invalidateQueries({ queryKey: inventoryKeys.all }),
      ]);
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};
