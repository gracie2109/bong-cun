import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  addExternalVaccination,
  giveVaccination,
  listMedicalReminders,
  listVaccineLots,
  markReminded,
  petVaccinations,
  voidVaccination,
} from "@/repositories/medical";
import { toPage, type PageParams } from "@bongcun/supabase/shared";
import type { ExternalVaccineInput, GiveVaccineInput, ReminderFilter } from "@/types/vaccination";
import { medicalKeys } from "./keys";
import { notifyMedicalFailure } from "./medical";
import { notifySuccess } from "./notify";

export const usePetBook = (petId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.book(unref(petId) ?? "")),
    queryFn: () => petVaccinations(supabaseClient(), unref(petId) as string),
    enabled: computed(() => !!unref(petId)),
  });

export const useVaccineLots = (branchId: MaybeRef<string | undefined>, typeId: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.lots(unref(branchId) ?? "", unref(typeId))),
    queryFn: () => listVaccineLots(supabaseClient(), unref(branchId) as string, unref(typeId)),
    enabled: computed(() => !!unref(branchId) && !!unref(typeId)),
  });

export const useMedicalReminders = (
  branchId: MaybeRef<string | undefined>,
  page: MaybeRef<PageParams>,
  filter: MaybeRef<ReminderFilter>
) =>
  useQuery({
    queryKey: computed(() => medicalKeys.reminders(unref(branchId) ?? "", toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listMedicalReminders(supabaseClient(), unref(branchId) as string, toPage(unref(page)), { ...unref(filter) }),
    enabled: computed(() => !!unref(branchId)),
    placeholderData: keepPreviousData,
  });

/** Mutation that refreshes every medical read and toasts the refusal the database gives. */
const useBookMutation = <TVars, TData>(mutationFn: (vars: TVars) => Promise<TData>, method: "create" | "update" | "delete") => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: medicalKeys.all });
      notifySuccess(method);
    },
    onError: (error) => notifyMedicalFailure(method, error),
  });
};

export const useGiveVaccine = () =>
  useBookMutation(({ visitId, input }: { visitId: string; input: GiveVaccineInput }) => giveVaccination(supabaseClient(), visitId, input), "create");

export const useAddExternalVaccine = () =>
  useBookMutation(({ petId, input }: { petId: string; input: ExternalVaccineInput }) => addExternalVaccination(supabaseClient(), petId, input), "create");

export const useVoidVaccine = () =>
  useBookMutation(({ id, reason }: { id: string; reason: string }) => voidVaccination(supabaseClient(), id, reason), "delete");

export const useMarkReminded = () =>
  useBookMutation(({ id, note }: { id: string; note: string }) => markReminded(supabaseClient(), id, note), "update");
