import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  addMedicalAddendum,
  addMedicalItem,
  assignMedicalVet,
  cancelMedicalVisit,
  checkInMedicalVisit,
  getMedicalPrescription,
  getMedicalQueue,
  getMedicalVisit,
  listMedicalVets,
  listMedicalVisits,
  markMedicalNoShow,
  petMedicalHistory,
  removeMedicalItem,
  saveMedicalRecord,
  scheduleMedicalVisit,
  signMedicalVisit,
  startMedicalVisit,
  updateMedicalItem,
} from "@bongcun/supabase/medical";
import { toPage, type PageParams } from "@bongcun/supabase/shared";
import type { CheckInInput, ItemDirections, ItemInput, RecordInput, ScheduleInput, VisitFilter } from "@bongcun/core/medical";
import { medicalKeys } from "./keys";
import { notifyMedicalFailure } from "./medical";
import { notifySuccess } from "./notify";

// ------------------------------------------------------------------- reads
/** The day's queue; it stays open at the front desk, so it refreshes by itself. */
export const useMedicalQueue = (branchId: MaybeRef<string | undefined>, date: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.queue(unref(branchId) ?? "", unref(date))),
    queryFn: () => getMedicalQueue(supabaseClient(), unref(branchId) as string, unref(date) || undefined),
    enabled: computed(() => !!unref(branchId)),
    refetchInterval: 30_000,
    refetchOnWindowFocus: true,
    placeholderData: keepPreviousData,
  });

export const useMedicalVisits = (
  branchId: MaybeRef<string | undefined>,
  page: MaybeRef<PageParams>,
  filter: MaybeRef<VisitFilter>
) =>
  useQuery({
    queryKey: computed(() => medicalKeys.visits(unref(branchId) ?? "", toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listMedicalVisits(supabaseClient(), unref(branchId) as string, toPage(unref(page)), { ...unref(filter) }),
    enabled: computed(() => !!unref(branchId)),
    placeholderData: keepPreviousData,
  });

export const useMedicalVisit = (id: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.visit(unref(id))),
    queryFn: () => getMedicalVisit(supabaseClient(), unref(id)),
    enabled: computed(() => !!unref(id)),
  });

export const usePetMedicalHistory = (petId: MaybeRef<string>, page: MaybeRef<PageParams>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.history(unref(petId), toPage(unref(page)))),
    queryFn: () => petMedicalHistory(supabaseClient(), unref(petId), toPage(unref(page))),
    enabled: computed(() => !!unref(petId)),
    placeholderData: keepPreviousData,
  });

export const useMedicalVets = (branchId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.vets(unref(branchId) ?? "")),
    queryFn: () => listMedicalVets(supabaseClient(), unref(branchId) as string),
    enabled: computed(() => !!unref(branchId)),
    staleTime: 5 * 60_000,
  });

export const useMedicalPrescription = (visitId: MaybeRef<string>, enabled: MaybeRef<boolean>) =>
  useQuery({
    queryKey: computed(() => [...medicalKeys.visit(unref(visitId)), "prescription"] as const),
    queryFn: () => getMedicalPrescription(supabaseClient(), unref(visitId)),
    enabled: computed(() => unref(enabled) && !!unref(visitId)),
  });

// ------------------------------------------------------------------ writes
/** Mutation that refreshes every medical read and toasts the refusal the database gives. */
const useVisitMutation = <TVars, TData>(
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

export const useCheckInVisit = () => useVisitMutation((input: CheckInInput) => checkInMedicalVisit(supabaseClient(), input), "create");

export const useScheduleVisit = () =>
  useVisitMutation(({ input, id }: { input: ScheduleInput; id?: string }) => scheduleMedicalVisit(supabaseClient(), input, id), "create");

export const useStartVisit = () => useVisitMutation((id: string) => startMedicalVisit(supabaseClient(), id), "update", { silent: true });

export const useAssignVet = () =>
  useVisitMutation(({ id, vetId }: { id: string; vetId: string | null }) => assignMedicalVet(supabaseClient(), id, vetId), "update");

export const useSaveRecord = () =>
  useVisitMutation(({ id, record }: { id: string; record: RecordInput }) => saveMedicalRecord(supabaseClient(), id, record), "update");

export const useSignVisit = () => useVisitMutation((id: string) => signMedicalVisit(supabaseClient(), id), "update");

export const useAddAddendum = () =>
  useVisitMutation(({ id, content }: { id: string; content: string }) => addMedicalAddendum(supabaseClient(), id, content), "create");

export const useCancelVisit = () =>
  useVisitMutation(({ id, reason }: { id: string; reason: string }) => cancelMedicalVisit(supabaseClient(), id, reason), "delete");

export const useMarkNoShow = () => useVisitMutation((id: string) => markMedicalNoShow(supabaseClient(), id), "update");

// ------------------------------------------------------------------- lines
export const useAddItem = () =>
  useVisitMutation(({ visitId, input }: { visitId: string; input: ItemInput }) => addMedicalItem(supabaseClient(), visitId, input), "create");

export const useUpdateItem = () =>
  useVisitMutation(
    ({ id, patch }: { id: string; patch: Partial<ItemDirections> & { qty?: number } }) => updateMedicalItem(supabaseClient(), id, patch),
    "update"
  );

export const useRemoveItem = () => useVisitMutation((id: string) => removeMedicalItem(supabaseClient(), id), "delete");
