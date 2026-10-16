import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { sendMessageToast } from "@/lib/utils";
import {
  getMedicalRules,
  listDiagnosisTerms,
  listVaccineTypes,
  medicalErrorDetail,
  medicalErrorHint,
  saveDiagnosisTerm,
  saveMedicalRules,
  saveVaccineType,
} from "@/repositories/medical";
import { toPage, type PageParams } from "@bongcun/supabase/shared";
import type { RestfullMethod } from "@/types";
import type {
  DiagnosisTermFilter,
  DiagnosisTermInput,
  MedicalRules,
  VaccineTypeFilter,
  VaccineTypeInput,
} from "@bongcun/core/medical";
import { medicalKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

/** Failure toast that turns the medical rules (duplicate name, bad protocol...) into text. */
export const notifyMedicalFailure = (method: RestfullMethod, error: unknown) => {
  const hint = medicalErrorHint(error);
  if (hint) {
    sendMessageToast("fail", method, "error", i18n.global.t(`medical.errors.${hint}`, { name: medicalErrorDetail(error) }));
  }
  else notifyFailure(method, error);
};

// -------------------------------------------------------- diagnosis terms
export const useDiagnosisTerms = (page: MaybeRef<PageParams>, filter: MaybeRef<DiagnosisTermFilter>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.diagnosisTerms(toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listDiagnosisTerms(supabaseClient(), toPage(unref(page)), { ...unref(filter) }),
    placeholderData: keepPreviousData,
  });

export const useSaveDiagnosisTerm = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ input, id }: { input: DiagnosisTermInput; id?: string }) => saveDiagnosisTerm(supabaseClient(), input, id),
    onSuccess: async (_data, { id }) => {
      await queryClient.invalidateQueries({ queryKey: medicalKeys.all });
      notifySuccess(id ? "update" : "create");
    },
    onError: (error, { id }) => notifyMedicalFailure(id ? "update" : "create", error),
  });
};

// ----------------------------------------------------------- vaccine types
export const useVaccineTypes = (
  branchId: MaybeRef<string | undefined>,
  page: MaybeRef<PageParams>,
  filter: MaybeRef<VaccineTypeFilter>
) =>
  useQuery({
    queryKey: computed(() => medicalKeys.vaccineTypes(unref(branchId) ?? "", toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listVaccineTypes(supabaseClient(), toPage(unref(page)), { ...unref(filter) }, unref(branchId)),
    placeholderData: keepPreviousData,
  });

export const useSaveVaccineType = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ input, id }: { input: VaccineTypeInput; id?: string }) => saveVaccineType(supabaseClient(), input, id),
    onSuccess: async (_data, { id }) => {
      await queryClient.invalidateQueries({ queryKey: medicalKeys.all });
      notifySuccess(id ? "update" : "create");
    },
    onError: (error, { id }) => notifyMedicalFailure(id ? "update" : "create", error),
  });
};

// ------------------------------------------------------------------- rules
export const useMedicalRules = (branchId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.rules(unref(branchId) ?? "")),
    queryFn: () => getMedicalRules(supabaseClient(), unref(branchId) as string),
    enabled: computed(() => !!unref(branchId)),
  });

export const useSaveMedicalRules = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ branchId, rules }: { branchId: string; rules: MedicalRules }) =>
      saveMedicalRules(supabaseClient(), branchId, rules),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: medicalKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifyMedicalFailure("update", error),
  });
};
