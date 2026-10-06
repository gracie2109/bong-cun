import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  createPetCombo,
  deletePetCombo,
  listPetCombos,
  type PetComboInput,
} from "@/repositories/petCombos";
import { toPage, type PageParams } from "@/repositories/shared";
import { petComboKeys } from "./keys";
import { invalidateCatalog } from "./invalidate";
import { notifyFailure, notifySuccess } from "./notify";

export const usePetCombosList = (page: MaybeRef<PageParams>) =>
  useQuery({
    queryKey: computed(() => petComboKeys.list(toPage(unref(page)))),
    queryFn: () => listPetCombos(supabaseClient(), toPage(unref(page))),
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

export const useDeletePetCombo = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deletePetCombo(supabaseClient(), id),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("delete");
    },
    onError: (error) => notifyFailure("delete", error),
  });
};
