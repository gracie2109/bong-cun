import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  addPetWeight,
  getPet,
  listPets,
  registerPet,
  setPetStatus,
  updatePet,
  type PetInput,
  type PetListFilter,
  type PetStatus,
  type RegisterPetInput,
} from "@/repositories/pets";
import { toPage, type PageParams } from "@/repositories/shared";
import { petProfileKeys } from "./keys";
import { invalidateCatalog } from "./invalidate";
import { notifyFailure, notifySuccess } from "./notify";

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
