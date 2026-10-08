import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { sendMessageToast } from "@/lib/utils";
import {
  getProductGroup,
  getSellableGroup,
  listProductAttributes,
  listProductGroups,
  productErrorHint,
  saveProductGroup,
  searchSellableProducts,
  setProductGroupActive,
  type ProductFilter,
  type ProductGroupInput,
} from "@/repositories/products";
import { errorDetail } from "@/repositories/pos";
import { toPage, type PageParams } from "@/repositories/shared";
import type { RestfullMethod } from "@/types";
import { inventoryKeys, productKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

/** Readable message for the variant rules (taken SKU, duplicate combination...), else the generic one. */
const notifyProductFailure = (method: RestfullMethod, error: unknown, subject = "") => {
  const hint = productErrorHint(error);
  if (!hint) return notifyFailure(method, error, subject);
  sendMessageToast("fail", method, "error", i18n.global.t(`products.errors.${hint}`, { value: errorDetail(error) || subject }));
};

export const useProductGroups = (page: MaybeRef<PageParams>, filter: MaybeRef<ProductFilter> = {}) =>
  useQuery({
    queryKey: computed(() => productKeys.groups(toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listProductGroups(supabaseClient(), toPage(unref(page)), { ...unref(filter) }),
    placeholderData: keepPreviousData,
  });

/** The group being edited, archived variants included. */
export const useProductGroup = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => productKeys.group(unref(id) ?? "")),
    queryFn: () => getProductGroup(supabaseClient(), unref(id) ?? ""),
    enabled: computed(() => Boolean(unref(id))),
  });

/** A group with its sellable variants only, for picking a variant at the counter or in the shop. */
export const useSellableGroup = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => productKeys.sellableGroup(unref(id) ?? "")),
    queryFn: () => getSellableGroup(supabaseClient(), unref(id) ?? ""),
    enabled: computed(() => Boolean(unref(id))),
  });

export const useProductAttributes = () =>
  useQuery({
    queryKey: productKeys.attributes(),
    queryFn: () => listProductAttributes(supabaseClient()),
  });

/** Active products matching the typed name, SKU or barcode (all of them while empty). */
export const useSellableProducts = (text: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => productKeys.sellable(unref(text).trim())),
    queryFn: () => searchSellableProducts(supabaseClient(), unref(text)),
    placeholderData: keepPreviousData,
  });

const useInvalidateCatalog = () => {
  const queryClient = useQueryClient();
  // Names, stock tracking and archiving change what the stock screens list.
  return () =>
    Promise.all([
      queryClient.invalidateQueries({ queryKey: productKeys.all }),
      queryClient.invalidateQueries({ queryKey: inventoryKeys.all }),
    ]);
};

export const useSaveProductGroup = () => {
  const invalidate = useInvalidateCatalog();
  return useMutation({
    mutationFn: (input: ProductGroupInput) => saveProductGroup(supabaseClient(), input),
    onSuccess: async (_id, input) => {
      await invalidate();
      notifySuccess(input.id ? "update" : "create");
    },
    onError: (error, input) => notifyProductFailure(input.id ? "update" : "create", error, input.name),
  });
};

export const useSetProductGroupActive = () => {
  const invalidate = useInvalidateCatalog();
  return useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      setProductGroupActive(supabaseClient(), id, isActive),
    onSuccess: async () => {
      await invalidate();
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};
