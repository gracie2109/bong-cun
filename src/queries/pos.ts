import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { sendMessageToast } from "@/lib/utils";
import {
  cancelInvoice,
  closeShift,
  createInvoice,
  createSalesReturn,
  errorDetail,
  getInvoice,
  getMyOpenShift,
  getShiftSummary,
  listCustomerPets,
  listInvoiceReturns,
  listInvoices,
  listSellableCombos,
  listShifts,
  openShift,
  posErrorHint,
  previewServicePrice,
  type InvoiceFilter,
  type SaleInput,
  type SalesReturnInput,
} from "@/repositories/pos";
import { toPage, type PageParams } from "@/repositories/shared";
import type { RestfullMethod } from "@/types";
import { customerKeys, inventoryKeys, posKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

/** Failure toast that turns the POS functions' hints (no open shift, underpaid...) into text. */
const notifyPosFailure = (method: RestfullMethod, error: unknown) => {
  const hint = posErrorHint(error);
  if (hint) {
    sendMessageToast("fail", method, "error", i18n.global.t(`pos.errors.${hint}`, { name: errorDetail(error) }));
  } else notifyFailure(method, error);
};

// Sales, cancellations and returns move stock, so stock screens refresh with the POS.
const invalidatePos = (queryClient: ReturnType<typeof useQueryClient>) =>
  Promise.all([
    queryClient.invalidateQueries({ queryKey: posKeys.all }),
    queryClient.invalidateQueries({ queryKey: inventoryKeys.all }),
  ]);

// ------------------------------------------------------------------ shifts
export const useMyOpenShift = (branchId: MaybeRef<string | undefined>, userId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => posKeys.myShift(unref(branchId) ?? "", unref(userId) ?? "")),
    queryFn: () => getMyOpenShift(supabaseClient(), unref(branchId) as string, unref(userId) as string),
    enabled: computed(() => !!unref(branchId) && !!unref(userId)),
  });

export const useShiftsList = (branchId: MaybeRef<string | undefined>, page: MaybeRef<PageParams>) =>
  useQuery({
    queryKey: computed(() => posKeys.shifts(unref(branchId) ?? "", toPage(unref(page)))),
    queryFn: () => listShifts(supabaseClient(), unref(branchId) as string, toPage(unref(page))),
    enabled: computed(() => !!unref(branchId)),
    placeholderData: keepPreviousData,
  });

export const useShiftSummary = (shiftId: MaybeRef<string | undefined>, enabled: MaybeRef<boolean> = true) =>
  useQuery({
    queryKey: computed(() => posKeys.shiftSummary(unref(shiftId) ?? "")),
    queryFn: () => getShiftSummary(supabaseClient(), unref(shiftId) as string),
    enabled: computed(() => !!unref(shiftId) && unref(enabled)),
  });

export const useOpenShift = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ branchId, openingCash, note }: { branchId: string; openingCash: number; note?: string }) =>
      openShift(supabaseClient(), branchId, openingCash, note),
    onSuccess: async () => {
      await invalidatePos(queryClient);
      notifySuccess("create");
    },
    onError: (error) => notifyPosFailure("create", error),
  });
};

export const useCloseShift = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ shiftId, countedCash, note }: { shiftId: string; countedCash: number; note?: string }) =>
      closeShift(supabaseClient(), shiftId, countedCash, note),
    onSuccess: async () => {
      await invalidatePos(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyPosFailure("update", error),
  });
};

// ---------------------------------------------------------------- invoices
export const useInvoicesList = (page: MaybeRef<PageParams>, filter: MaybeRef<InvoiceFilter | null>) =>
  useQuery({
    queryKey: computed(() => posKeys.invoices(toPage(unref(page)), { ...(unref(filter) as InvoiceFilter) })),
    queryFn: () => listInvoices(supabaseClient(), toPage(unref(page)), { ...(unref(filter) as InvoiceFilter) }),
    enabled: computed(() => !!unref(filter)),
    placeholderData: keepPreviousData,
  });

export const useInvoice = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => posKeys.invoice(unref(id) ?? "")),
    queryFn: () => getInvoice(supabaseClient(), unref(id) as string),
    enabled: computed(() => !!unref(id)),
  });

export const useCreateInvoice = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: SaleInput) => createInvoice(supabaseClient(), input),
    onSuccess: async () => {
      // A walk-in typed at the counter becomes a customer.
      await Promise.all([invalidatePos(queryClient), queryClient.invalidateQueries({ queryKey: customerKeys.all })]);
    },
    onError: (error) => notifyPosFailure("create", error),
  });
};

export const useCancelInvoice = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => cancelInvoice(supabaseClient(), id, reason),
    onSuccess: async () => {
      await invalidatePos(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyPosFailure("update", error),
  });
};

// ------------------------------------------------------------------ returns
export const useInvoiceReturns = (invoiceId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => posKeys.invoiceReturns(unref(invoiceId) ?? "")),
    queryFn: () => listInvoiceReturns(supabaseClient(), unref(invoiceId) as string),
    enabled: computed(() => !!unref(invoiceId)),
  });

export const useCreateSalesReturn = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: SalesReturnInput) => createSalesReturn(supabaseClient(), input),
    onSuccess: async () => {
      await invalidatePos(queryClient);
      notifySuccess("create");
    },
    onError: (error) => notifyPosFailure("create", error),
  });
};

// ------------------------------------------------------------ cart helpers
export const useSellableCombos = () =>
  useQuery({ queryKey: posKeys.combos(), queryFn: () => listSellableCombos(supabaseClient()) });

export const useCustomerPets = (customerId: MaybeRef<string | null | undefined>) =>
  useQuery({
    queryKey: computed(() => posKeys.customerPets(unref(customerId) ?? "")),
    queryFn: () => listCustomerPets(supabaseClient(), unref(customerId) as string),
    enabled: computed(() => !!unref(customerId)),
  });

/** Imperative price preview for a by-weight service line (cached per species, weight and branch). */
export const useFetchServicePrice = () => {
  const queryClient = useQueryClient();
  return (args: { speciesId: string; serviceId: string; weightKg: number; branchId: string }) =>
    queryClient.fetchQuery({
      queryKey: posKeys.servicePrice(args.speciesId, args.serviceId, args.weightKg, args.branchId),
      queryFn: () => previewServicePrice(supabaseClient(), args),
    });
};
