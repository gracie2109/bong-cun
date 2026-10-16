import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  createSpecies,
  getSpecies,
  listSpecies,
  listSpeciesSummaries,
  setSpeciesActive,
  updateSpecies,
  type SpeciesInput,
} from "@/repositories/species";
import { speciesKeys } from "./keys";
import { invalidateCatalog } from "./invalidate";
import { notifyFailure, notifySuccess } from "./notify";

/** Active species, for selectors; pass `includeArchived` to list archived ones too. */
export const useSpeciesOptions = (includeArchived: MaybeRef<boolean> = false) =>
  useQuery({
    queryKey: computed(() => speciesKeys.options(unref(includeArchived))),
    queryFn: () => listSpecies(supabaseClient(), { includeArchived: unref(includeArchived) }),
  });

/** The catalog page: every species with its pet and service counters. */
export const useSpeciesSummaries = () =>
  useQuery({ queryKey: speciesKeys.summaries(), queryFn: () => listSpeciesSummaries(supabaseClient()) });

export const useSpecies = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => speciesKeys.detail(unref(id) ?? "")),
    queryFn: () => getSpecies(supabaseClient(), unref(id) as string),
    enabled: computed(() => !!unref(id)),
  });

export const useCreateSpecies = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: SpeciesInput) => createSpecies(supabaseClient(), input),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("create");
    },
    onError: (error, input) => notifyFailure("create", error, input.name),
  });
};

export const useUpdateSpecies = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: SpeciesInput }) =>
      updateSpecies(supabaseClient(), id, input),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error, { input }) => notifyFailure("update", error, input.name),
  });
};

export const useSetSpeciesActive = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      setSpeciesActive(supabaseClient(), id, isActive),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};
