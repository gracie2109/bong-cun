import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabase } from "@/plugins/supabase";
import {
  createPet,
  deletePet,
  getPet,
  listAllPets,
  listPets,
  updatePet,
  type PetInput,
} from "@/repositories/pets";
import { toPage, type PageParams } from "@/repositories/shared";
import { petKeys } from "./keys";
import { invalidateCatalog } from "./invalidate";
import { notifyFailure, notifySuccess } from "./notify";

export const usePetsList = (page: MaybeRef<PageParams>) =>
  useQuery({
    queryKey: computed(() => petKeys.list(toPage(unref(page)))),
    queryFn: () => listPets(supabase, toPage(unref(page))),
    placeholderData: keepPreviousData,
  });

/** All pets, for selectors. */
export const useAllPets = () =>
  useQuery({ queryKey: petKeys.options(), queryFn: () => listAllPets(supabase) });

export const usePet = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => petKeys.detail(unref(id) ?? "")),
    queryFn: () => getPet(supabase, unref(id) as string),
    enabled: computed(() => !!unref(id)),
  });

export const useCreatePet = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: PetInput) => createPet(supabase, input),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("create");
    },
    onError: (error, input) => notifyFailure("create", error, input.name),
  });
};

export const useUpdatePet = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: PetInput }) => updatePet(supabase, id, input),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error, { input }) => notifyFailure("update", error, input.name),
  });
};

export const useDeletePet = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deletePet(supabase, id),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("delete");
    },
    onError: (error) => notifyFailure("delete", error),
  });
};
