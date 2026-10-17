import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  addPetWeight,
  getPet,
  listPets,
  markPetDeceased,
  petDeceasedPreview,
  registerPet,
  restorePet,
  setPetStatus,
  updatePet,
  type PetInput,
  type PetListFilter,
  type MarkDeceasedInput,
  type PetStatus,
  type RegisterPetInput,
} from "@bongcun/supabase/pets";
import { toPage, type PageParams } from "@bongcun/supabase/shared";
import { petProfileKeys } from "@/queries/keys";
import { invalidateCatalog } from "@/queries/invalidate";
import { notifyMedicalFailure } from "@/features/admin/medical";
import { notifyFailure, notifySuccess } from "@/queries/notify";

export const usePetsList = (page: MaybeRef<PageParams>, filter: MaybeRef<PetListFilter> = {}) =>
  useQuery({
    queryKey: computed(() => petProfileKeys.list(toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listPets(supabaseClient(), toPage(unref(page)), { ...unref(filter) }),
    placeholderData: keepPreviousData,
  });

export const usePet = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => petProfileKeys.detail(unref(id) ?? "")),
    queryFn: () => getPet(supabaseClient(), unref(id) as string),
    enabled: computed(() => !!unref(id)),
  });

export const useRegisterPet = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: RegisterPetInput) => registerPet(supabaseClient(), input),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("create");
    },
    onError: (error, input) => notifyFailure("create", error, input.pet.name),
  });
};

export const useUpdatePet = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: PetInput }) =>
      updatePet(supabaseClient(), id, input),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error, { input }) => notifyFailure("update", error, input.name),
  });
};

export const useSetPetStatus = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, status }: { id: string; status: PetStatus }) =>
      setPetStatus(supabaseClient(), id, status),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};

export const useAddPetWeight = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (args: { petId: string; weightKg: number; note?: string | null }) =>
      addPetWeight(supabaseClient(), args.petId, args.weightKg, args.note),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("create");
    },
    onError: (error) => notifyFailure("create", error),
  });
};

/** What marking the pet deceased would cancel; only fetched while the dialog is open. */
export const usePetDeceasedPreview = (id: MaybeRef<string | undefined>, enabled: MaybeRef<boolean>) =>
  useQuery({
    queryKey: computed(() => [...petProfileKeys.detail(unref(id) ?? ""), "deceased-preview"] as const),
    queryFn: () => petDeceasedPreview(supabaseClient(), unref(id) as string),
    enabled: computed(() => !!unref(id) && unref(enabled)),
    gcTime: 0,
  });

// Bookings, stays and visits of the pet change too, so every screen that is open refreshes.
export const useMarkPetDeceased = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: MarkDeceasedInput }) =>
      markPetDeceased(supabaseClient(), id, input),
    onSuccess: async () => {
      await queryClient.invalidateQueries();
      notifySuccess("update");
    },
    onError: (error) => notifyMedicalFailure("update", error),
  });
};

export const useRestorePet = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => restorePet(supabaseClient(), id),
    onSuccess: async () => {
      await queryClient.invalidateQueries();
      notifySuccess("update");
    },
    onError: (error) => notifyMedicalFailure("update", error),
  });
};
