import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  createPetCombo,
  listPetCombos,
  setPetComboActive,
  updatePetCombo,
  type PetComboInput,
} from "@/repositories/petCombos";
import { toPage, type PageParams } from "@/repositories/shared";
import { petComboKeys } from "./keys";
import { invalidateCatalog } from "./invalidate";
import { notifyFailure, notifySuccess } from "./notify";

export const usePetCombosList = (
  page: MaybeRef<PageParams>,
  includeArchived: MaybeRef<boolean> = false,
  search: MaybeRef<string> = ""
) =>
  useQuery({
    queryKey: computed(() => petComboKeys.list(toPage(unref(page)), unref(includeArchived), unref(search))),
    queryFn: () =>
      listPetCombos(supabaseClient(), toPage(unref(page)), {
        includeArchived: unref(includeArchived),
        search: unref(search),
      }),
    placeholderData: keepPreviousData,
  });

export const useCreatePetCombo = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: PetComboInput) => createPetCombo(supabaseClient(), input),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("create");
    },
    onError: (error, input) => notifyFailure("create", error, input.name),
  });
};

export const useUpdatePetCombo = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: PetComboInput }) =>
      updatePetCombo(supabaseClient(), id, input),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error, { input }) => notifyFailure("update", error, input.name),
  });
};

export const useSetPetComboActive = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      setPetComboActive(supabaseClient(), id, isActive),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};
