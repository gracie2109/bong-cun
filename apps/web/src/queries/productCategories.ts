import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { useInfiniteOptions } from "@/composables/useInfiniteOptions";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { sendMessageToast } from "@/lib/utils";
import {
  catalogErrorHint,
  deleteProductBrand,
  deleteProductCategory,
  listProductBrands,
  listProductCategories,
  moveProductCategory,
  saveProductBrand,
  saveProductCategory,
  type CatalogFilter,
  type ProductBrandInput,
  type ProductCategoryInput,
} from "@bongcun/supabase/products";
import { toPage, type PageParams } from "@bongcun/supabase/shared";
import type { RestfullMethod } from "@/types";
import { productBrandKeys, productCategoryKeys, productKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

/** Readable message for the category and brand rules (taken name, still in use...), else the generic one. */
const notifyCatalogFailure = (method: RestfullMethod, error: unknown, subject = "") => {
  const hint = catalogErrorHint(error);
  if (!hint) return notifyFailure(method, error, subject);
  sendMessageToast("fail", method, "error", i18n.global.t(`productCatalog.errors.${hint}`, { value: subject }));
};

export const useProductCategories = (page: MaybeRef<PageParams>, filter: MaybeRef<CatalogFilter> = {}) =>
  useQuery({
    queryKey: computed(() => productCategoryKeys.list(toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listProductCategories(supabaseClient(), toPage(unref(page)), { ...unref(filter) }),
    placeholderData: keepPreviousData,
  });

export const useProductBrands = (page: MaybeRef<PageParams>, filter: MaybeRef<CatalogFilter> = {}) =>
  useQuery({
    queryKey: computed(() => productBrandKeys.list(toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listProductBrands(supabaseClient(), toPage(unref(page)), { ...unref(filter) }),
    placeholderData: keepPreviousData,
  });

/** Active categories for a select that loads more as it scrolls and searches on the server. */
export const useProductCategoryOptions = (search: MaybeRef<string>, rootsOnly = false) =>
  useInfiniteOptions({
    queryKey: (text) => productCategoryKeys.options(text, rootsOnly),
    fetchPage: (page, text) => listProductCategories(supabaseClient(), page, { search: text, rootsOnly }),
    search,
  });

export const useProductBrandOptions = (search: MaybeRef<string>) =>
  useInfiniteOptions({
    queryKey: productBrandKeys.options,
    fetchPage: (page, text) => listProductBrands(supabaseClient(), page, { search: text }),
    search,
  });

const useInvalidateCatalog = () => {
  const queryClient = useQueryClient();
  // The product list shows the category and brand names too.
  return () =>
    Promise.all([
      queryClient.invalidateQueries({ queryKey: productCategoryKeys.all }),
      queryClient.invalidateQueries({ queryKey: productBrandKeys.all }),
      queryClient.invalidateQueries({ queryKey: productKeys.all }),
    ]);
};

export const useSaveProductCategory = () => {
  const invalidate = useInvalidateCatalog();
  return useMutation({
    mutationFn: (input: ProductCategoryInput) => saveProductCategory(supabaseClient(), input),
    onSuccess: async (_id, input) => {
      await invalidate();
      notifySuccess(input.id ? "update" : "create");
    },
    onError: (error, input) => notifyCatalogFailure(input.id ? "update" : "create", error, input.name),
  });
};

export const useMoveProductCategory = () => {
  const invalidate = useInvalidateCatalog();
  return useMutation({
    mutationFn: ({ id, direction }: { id: string; direction: "up" | "down" }) =>
      moveProductCategory(supabaseClient(), id, direction),
    onSuccess: invalidate,
    onError: (error) => notifyFailure("update", error),
  });
};

export const useDeleteProductCategory = () => {
  const invalidate = useInvalidateCatalog();
  return useMutation({
    mutationFn: (id: string) => deleteProductCategory(supabaseClient(), id),
    onSuccess: async () => {
      await invalidate();
      notifySuccess("delete");
    },
    onError: (error) => notifyCatalogFailure("delete", error),
  });
};

export const useSaveProductBrand = () => {
  const invalidate = useInvalidateCatalog();
  return useMutation({
    mutationFn: (input: ProductBrandInput) => saveProductBrand(supabaseClient(), input),
    onSuccess: async (_id, input) => {
      await invalidate();
      notifySuccess(input.id ? "update" : "create");
    },
    onError: (error, input) => notifyCatalogFailure(input.id ? "update" : "create", error, input.name),
  });
};

export const useDeleteProductBrand = () => {
  const invalidate = useInvalidateCatalog();
  return useMutation({
    mutationFn: (id: string) => deleteProductBrand(supabaseClient(), id),
    onSuccess: async () => {
      await invalidate();
      notifySuccess("delete");
    },
    onError: (error) => notifyCatalogFailure("delete", error),
  });
};
