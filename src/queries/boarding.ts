import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { sendMessageToast } from "@/lib/utils";
import {
  boardingErrorHint,
  getBoardingRules,
  listKennels,
  listKennelTypes,
  saveBoardingRules,
  saveKennel,
  saveKennelType,
  setKennelStatus,
} from "@/repositories/boarding";
import { toPage, type PageParams } from "@/repositories/shared";
import type {
  BoardingRules,
  KennelFilter,
  KennelInput,
  KennelStatus,
  KennelTypeFilter,
  KennelTypeInput,
} from "@/types/boarding";
import type { RestfullMethod } from "@/types";
import { boardingKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

/** Failure toast that turns the boarding rules (duplicate code, bad hours...) into text. */
const notifyBoardingFailure = (method: RestfullMethod, error: unknown) => {
  const hint = boardingErrorHint(error);
  if (hint) sendMessageToast("fail", method, "error", i18n.global.t(`boarding.errors.${hint}`));
  else notifyFailure(method, error);
};

// ----------------------------------------------------------- kennel types
export const useKennelTypes = (
  branchId: MaybeRef<string | undefined>,
  page: MaybeRef<PageParams>,
  filter: MaybeRef<KennelTypeFilter>
) =>
  useQuery({
    queryKey: computed(() => boardingKeys.kennelTypes(unref(branchId) ?? "", toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listKennelTypes(supabaseClient(), unref(branchId) as string, toPage(unref(page)), { ...unref(filter) }),
    enabled: computed(() => !!unref(branchId)),
    placeholderData: keepPreviousData,
  });

export const useSaveKennelType = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ input, id }: { input: KennelTypeInput; id?: string }) => saveKennelType(supabaseClient(), input, id),
    onSuccess: async (_data, { id }) => {
      await queryClient.invalidateQueries({ queryKey: boardingKeys.all });
      notifySuccess(id ? "update" : "create");
    },
    onError: (error, { id }) => notifyBoardingFailure(id ? "update" : "create", error),
  });
};

// ------------------------------------------------------------------ kennels
export const useKennels = (
  branchId: MaybeRef<string | undefined>,
  page: MaybeRef<PageParams>,
  filter: MaybeRef<KennelFilter>
) =>
  useQuery({
    queryKey: computed(() => boardingKeys.kennels(unref(branchId) ?? "", toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listKennels(supabaseClient(), unref(branchId) as string, toPage(unref(page)), { ...unref(filter) }),
    enabled: computed(() => !!unref(branchId)),
    placeholderData: keepPreviousData,
  });

export const useSaveKennel = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ input, id }: { input: KennelInput; id?: string }) => saveKennel(supabaseClient(), input, id),
    onSuccess: async (_data, { id }) => {
      await queryClient.invalidateQueries({ queryKey: boardingKeys.all });
      notifySuccess(id ? "update" : "create");
    },
    onError: (error, { id }) => notifyBoardingFailure(id ? "update" : "create", error),
  });
};

export const useSetKennelStatus = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, status }: { id: string; status: KennelStatus }) => setKennelStatus(supabaseClient(), id, status),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: boardingKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifyBoardingFailure("update", error),
  });
};

// -------------------------------------------------------------------- rules
export const useBoardingRules = (branchId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => boardingKeys.rules(unref(branchId) ?? "")),
    queryFn: () => getBoardingRules(supabaseClient(), unref(branchId) as string),
    enabled: computed(() => !!unref(branchId)),
  });

export const useSaveBoardingRules = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ branchId, rules }: { branchId: string; rules: BoardingRules }) =>
      saveBoardingRules(supabaseClient(), branchId, rules),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: boardingKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifyBoardingFailure("update", error),
  });
};
