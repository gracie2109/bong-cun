import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { sendMessageToast } from "@/lib/utils";
import {
  cancelStockDocument,
  createSupplier,
  getSellableStock,
  getStockAlertCounts,
  getStockDocument,
  getStockSummary,
  inventoryErrorHint,
  listProductLots,
  listProductMovements,
  listStockDocuments,
  listSupplierOptions,
  listSuppliers,
  postStockDocument,
  saveStockDocument,
  setMinStock,
  updateSupplier,
  type StockDocumentFilter,
  type StockDocumentInput,
  type StockFilter,
  type SupplierFilter,
  type SupplierInput,
} from "@/repositories/inventory";
import { errorDetail } from "@/repositories/pos";
import { toPage, type PageParams } from "@/repositories/shared";
import type { RestfullMethod } from "@/types";
import { inventoryKeys, supplierKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

/** Failure toast that turns the stock functions' hints (lot short, needs a manager...) into text. */
const notifyInventoryFailure = (method: RestfullMethod, error: unknown) => {
  const hint = inventoryErrorHint(error);
  if (hint) {
    sendMessageToast("fail", method, "error", i18n.global.t(`inventory.errors.${hint}`, { name: errorDetail(error) }));
  } else notifyFailure(method, error);
};

const invalidateInventory = (queryClient: ReturnType<typeof useQueryClient>) =>
  queryClient.invalidateQueries({ queryKey: inventoryKeys.all });

// --------------------------------------------------------------------- stock
export const useStockSummary = (page: MaybeRef<PageParams>, filter: MaybeRef<StockFilter | null>) =>
  useQuery({
    queryKey: computed(() => inventoryKeys.summary(toPage(unref(page)), { ...(unref(filter) as StockFilter) })),
    queryFn: () => getStockSummary(supabaseClient(), toPage(unref(page)), { ...(unref(filter) as StockFilter) }),
    enabled: computed(() => !!unref(filter)),
    placeholderData: keepPreviousData,
  });

export const useStockAlertCounts = (branchId: MaybeRef<string | undefined>, expiryDays: MaybeRef<number>) =>
  useQuery({
    queryKey: computed(() => inventoryKeys.alerts(unref(branchId) ?? "", unref(expiryDays))),
    queryFn: () => getStockAlertCounts(supabaseClient(), unref(branchId) as string, unref(expiryDays)),
    enabled: computed(() => !!unref(branchId)),
  });

/** Unexpired stock of the given products at a branch (products without stock tracking are absent). */
export const useSellableStock = (branchId: MaybeRef<string | undefined>, productIds: MaybeRef<string[]>) =>
  useQuery({
    queryKey: computed(() => inventoryKeys.sellable(unref(branchId) ?? "", unref(productIds))),
    queryFn: () => getSellableStock(supabaseClient(), unref(branchId) as string, unref(productIds)),
    enabled: computed(() => !!unref(branchId) && unref(productIds).length > 0),
    placeholderData: keepPreviousData,
  });

export const useProductLots = (
  branchId: MaybeRef<string | undefined>,
  productId: MaybeRef<string | undefined>,
  includeEmpty: MaybeRef<boolean> = false
) =>
  useQuery({
    queryKey: computed(() =>
      inventoryKeys.lots(unref(branchId) ?? "", unref(productId) ?? "", unref(includeEmpty))
    ),
    queryFn: () =>
      listProductLots(supabaseClient(), unref(branchId) as string, unref(productId) as string, unref(includeEmpty)),
    enabled: computed(() => !!unref(branchId) && !!unref(productId)),
  });

/** Imperative lot lookup for document editors (adding a product to a write-off or a count). */
export const useFetchProductLots = () => {
  const queryClient = useQueryClient();
  return (branchId: string, productId: string) =>
    queryClient.fetchQuery({
      queryKey: inventoryKeys.lots(branchId, productId, false),
      queryFn: () => listProductLots(supabaseClient(), branchId, productId),
    });
};

export const useProductMovements = (branchId: MaybeRef<string | undefined>, productId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => inventoryKeys.movements(unref(branchId) ?? "", unref(productId) ?? "")),
    queryFn: () => listProductMovements(supabaseClient(), unref(branchId) as string, unref(productId) as string),
    enabled: computed(() => !!unref(branchId) && !!unref(productId)),
  });

export const useSetMinStock = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ branchId, productId, minQty }: { branchId: string; productId: string; minQty: number | null }) =>
      setMinStock(supabaseClient(), branchId, productId, minQty),
    onSuccess: async () => {
      await invalidateInventory(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyInventoryFailure("update", error),
  });
};

// ----------------------------------------------------------------- documents
export const useStockDocuments = (page: MaybeRef<PageParams>, filter: MaybeRef<StockDocumentFilter | null>) =>
  useQuery({
    queryKey: computed(() =>
      inventoryKeys.documents(toPage(unref(page)), { ...(unref(filter) as StockDocumentFilter) })
    ),
    queryFn: () =>
      listStockDocuments(supabaseClient(), toPage(unref(page)), { ...(unref(filter) as StockDocumentFilter) }),
    enabled: computed(() => !!unref(filter)),
    placeholderData: keepPreviousData,
  });

export const useStockDocument = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => inventoryKeys.document(unref(id) ?? "")),
    queryFn: () => getStockDocument(supabaseClient(), unref(id) as string),
    enabled: computed(() => !!unref(id)),
  });

/** Creates or replaces a draft; resolves with its id. `quiet` skips the toast when a post follows. */
export const useSaveStockDocument = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ input }: { input: StockDocumentInput; quiet?: boolean }) => saveStockDocument(supabaseClient(), input),
    onSuccess: async (_id, { input, quiet }) => {
      await invalidateInventory(queryClient);
      if (!quiet) notifySuccess(input.id ? "update" : "create");
    },
    onError: (error, { input }) => notifyInventoryFailure(input.id ? "update" : "create", error),
  });
};

export const usePostStockDocument = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => postStockDocument(supabaseClient(), id),
    onSuccess: async () => {
      await invalidateInventory(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyInventoryFailure("update", error),
  });
};

export const useCancelStockDocument = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason?: string }) => cancelStockDocument(supabaseClient(), id, reason),
    onSuccess: async () => {
      await invalidateInventory(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyInventoryFailure("update", error),
  });
};

// ----------------------------------------------------------------- suppliers
export const useSuppliersList = (page: MaybeRef<PageParams>, filter: MaybeRef<SupplierFilter> = {}) =>
  useQuery({
    queryKey: computed(() => supplierKeys.list(toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listSuppliers(supabaseClient(), toPage(unref(page)), { ...unref(filter) }),
    placeholderData: keepPreviousData,
  });

export const useSupplierOptions = () =>
  useQuery({ queryKey: supplierKeys.options(), queryFn: () => listSupplierOptions(supabaseClient()) });

export const useSaveSupplier = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id?: string; input: SupplierInput }) =>
      id ? updateSupplier(supabaseClient(), id, input) : createSupplier(supabaseClient(), input),
    onSuccess: async (_data, { id }) => {
      await queryClient.invalidateQueries({ queryKey: supplierKeys.all });
      notifySuccess(id ? "update" : "create");
    },
    onError: (error, { id, input }) => notifyFailure(id ? "update" : "create", error, input.name),
  });
};
