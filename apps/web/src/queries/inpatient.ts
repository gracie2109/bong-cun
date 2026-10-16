import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { sendMessageToast } from "@/lib/utils";
import {
  addInpatientLog,
  admitInpatient,
  dischargeInpatient,
  getInpatientOrderHistory,
  getInpatientWard,
  giveInpatientDose,
  listInpatientKennels,
  replaceInpatientOrder,
  saveInpatientOrder,
  skipInpatientDose,
  stopInpatientOrder,
  updateInpatientOrder,
} from "@bongcun/supabase/medical";
import type { AdmitInput, LogKind, OrderInput, UpdateOrderInput } from "@bongcun/core/medical";
import { medicalKeys } from "./keys";
import { notifyMedicalFailure } from "./medical";
import { notifySuccess } from "./notify";

// ------------------------------------------------------------------- reads
/** The in-patients and the doses of one day; it stays open on a tablet, so it refreshes by itself. */
export const useInpatientWard = (branchId: MaybeRef<string | undefined>, date: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.ward(unref(branchId) ?? "", unref(date))),
    queryFn: () => getInpatientWard(supabaseClient(), unref(branchId) as string, unref(date) || undefined),
    enabled: computed(() => !!unref(branchId)),
    refetchInterval: 30_000,
    refetchOnWindowFocus: true,
    placeholderData: keepPreviousData,
  });

export const useInpatientKennels = (branchId: MaybeRef<string | undefined>, enabled: MaybeRef<boolean>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.kennels(unref(branchId) ?? "")),
    queryFn: () => listInpatientKennels(supabaseClient(), unref(branchId) as string),
    enabled: computed(() => !!unref(branchId) && unref(enabled)),
  });

/** The change log of one order; it loads when the popover opens. */
export const useOrderHistory = (orderId: MaybeRef<string | undefined>, enabled: MaybeRef<boolean>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.orderHistory(unref(orderId) ?? "")),
    queryFn: () => getInpatientOrderHistory(supabaseClient(), unref(orderId) as string),
    enabled: computed(() => !!unref(orderId) && unref(enabled)),
  });

// ------------------------------------------------------------------ writes
const useWardMutation = <TVars, TData>(
  mutationFn: (vars: TVars) => Promise<TData>,
  method: "create" | "update" | "delete",
  options: { silent?: boolean } = {}
) => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: medicalKeys.all });
      if (!options.silent) notifySuccess(method);
    },
    onError: (error) => notifyMedicalFailure(method, error),
  });
};

export const useAdmitInpatient = () =>
  useWardMutation(({ visitId, input }: { visitId: string; input: AdmitInput }) => admitInpatient(supabaseClient(), visitId, input), "create");

export const useSaveOrder = () => useWardMutation((input: OrderInput) => saveInpatientOrder(supabaseClient(), input), "create");

export const useStopOrder = () =>
  useWardMutation(({ id, reason }: { id: string; reason?: string }) => stopInpatientOrder(supabaseClient(), id, reason), "update");

export const useUpdateOrder = () =>
  useWardMutation(({ id, input }: { id: string; input: UpdateOrderInput }) => updateInpatientOrder(supabaseClient(), id, input), "update");

/** Another medicine for the same pet: stops the old order and starts the new one. */
export const useReplaceOrder = () =>
  useWardMutation(
    ({ id, input, reason }: { id: string; input: OrderInput; reason?: string }) => replaceInpatientOrder(supabaseClient(), id, input, reason),
    "update"
  );

export const useGiveDose = () => {
  const mutation = useWardMutation(
    async (id: string) => {
      const warnings = await giveInpatientDose(supabaseClient(), id);
      if (warnings.includes("low_stock")) sendMessageToast("fail", "update", "error", i18n.global.t("medical.items.lowStock"));
    },
    "update",
    { silent: true }
  );
  return mutation;
};

export const useSkipDose = () =>
  useWardMutation(({ id, reason }: { id: string; reason: string }) => skipInpatientDose(supabaseClient(), id, reason), "update", { silent: true });

export const useAddLog = () =>
  useWardMutation(({ stayPetId, kind, content }: { stayPetId: string; kind: LogKind; content: string }) => addInpatientLog(supabaseClient(), stayPetId, kind, content), "create");

export const useDischarge = () => useWardMutation((stayId: string) => dischargeInpatient(supabaseClient(), stayId), "update");
