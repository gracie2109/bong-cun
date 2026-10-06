import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabase } from "@/plugins/supabase";
import {
  createPetService,
  deletePetService,
  getPetService,
  listAllPetServices,
  listPetServices,
  listServicesOfPets,
  updateGeneralPrice,
  updatePetService,
  type PetServiceInput,
} from "@/repositories/petServices";
import { toPage, type PageParams } from "@/repositories/shared";
import { petServiceKeys } from "./keys";
import { invalidateCatalog } from "./invalidate";
import { notifyFailure, notifySuccess } from "./notify";

export const usePetServicesList = (page: MaybeRef<PageParams>) =>
  useQuery({
    queryKey: computed(() => petServiceKeys.list(toPage(unref(page)))),
    queryFn: () => listPetServices(supabase, toPage(unref(page))),
    placeholderData: keepPreviousData,
  });

export const useAllPetServices = () =>
  useQuery({ queryKey: petServiceKeys.options(), queryFn: () => listAllPetServices(supabase) });

export const usePetService = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => petServiceKeys.detail(unref(id) ?? "")),
    queryFn: () => getPetService(supabase, unref(id) as string),
    enabled: computed(() => !!unref(id)),
  });

/** Imperative lookup (used from a watcher): services offered for the given pets. */
export const useFetchServicesOfPets = () => {
  const queryClient = useQueryClient();
  return (petIds: string[]) =>
    queryClient.fetchQuery({
      queryKey: petServiceKeys.ofPets(petIds),
      queryFn: () => listServicesOfPets(supabase, petIds),
    });
};

export const useCreatePetService = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: PetServiceInput) => createPetService(supabase, input),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("create");
    },
    onError: (error, input) => notifyFailure("create", error, input.name),
  });
};

export const useUpdatePetService = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: PetServiceInput }) =>
      updatePetService(supabase, id, input),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error, { input }) => notifyFailure("update", error, input.name),
  });
};

export const useDeletePetService = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deletePetService(supabase, id),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("delete");
    },
    onError: (error) => notifyFailure("delete", error),
  });
};

export const useUpdateGeneralPrice = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, generalPrice }: { id: string; generalPrice: number | null }) =>
      updateGeneralPrice(supabase, id, generalPrice),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};
