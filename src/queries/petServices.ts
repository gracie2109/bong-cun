import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  createPetService,
  getPetService,
  listAllPetServices,
  listPetServices,
  listServicesOfSpecies,
  setPetServiceActive,
  updateGeneralPrice,
  updatePetService,
  type PetServiceFilter,
  type PetServiceInput,
} from "@/repositories/petServices";
import { toPage, type PageParams } from "@/repositories/shared";
import { petServiceKeys } from "./keys";
import { invalidateCatalog } from "./invalidate";
import { notifyFailure, notifySuccess } from "./notify";

export const usePetServicesList = (
  page: MaybeRef<PageParams>,
  filter: MaybeRef<PetServiceFilter> = {}
) =>
  useQuery({
    queryKey: computed(() => petServiceKeys.list(toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listPetServices(supabaseClient(), toPage(unref(page)), { ...unref(filter) }),
    placeholderData: keepPreviousData,
  });

export const useAllPetServices = () =>
  useQuery({ queryKey: petServiceKeys.options(), queryFn: () => listAllPetServices(supabaseClient()) });

export const usePetService = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => petServiceKeys.detail(unref(id) ?? "")),
    queryFn: () => getPetService(supabaseClient(), unref(id) as string),
    enabled: computed(() => !!unref(id)),
  });

/** Imperative lookup (used from a watcher): services offered for the given species. */
export const useFetchServicesOfSpecies = () => {
  const queryClient = useQueryClient();
  return (speciesIds: string[]) =>
    queryClient.fetchQuery({
      queryKey: petServiceKeys.ofSpecies(speciesIds),
      queryFn: () => listServicesOfSpecies(supabaseClient(), speciesIds),
    });
};

export const useCreatePetService = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: PetServiceInput) => createPetService(supabaseClient(), input),
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
      updatePetService(supabaseClient(), id, input),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error, { input }) => notifyFailure("update", error, input.name),
  });
};

export const useSetPetServiceActive = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      setPetServiceActive(supabaseClient(), id, isActive),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};

export const useUpdateGeneralPrice = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, generalPrice }: { id: string; generalPrice: number | null }) =>
      updateGeneralPrice(supabaseClient(), id, generalPrice),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};
