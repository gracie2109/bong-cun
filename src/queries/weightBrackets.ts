import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  listWeightBrackets,
  saveWeightBrackets,
  type WeightBracketInput,
} from "@/repositories/weightBrackets";
import { weightBracketKeys } from "./keys";
import { invalidateCatalog } from "./invalidate";
import { notifyFailure, notifySuccess } from "./notify";

/**
 * Brackets of one species, or of all species when no id is given. Pass `enabled: false` to wait
 * until a species is chosen (otherwise an empty id would load the brackets of every species).
 */
export const useWeightBrackets = (
  speciesId: MaybeRef<string | undefined> = undefined,
  options: { enabled?: MaybeRef<boolean> } = {}
) =>
  useQuery({
    queryKey: computed(() => weightBracketKeys.list(unref(speciesId) ?? null)),
    queryFn: () => listWeightBrackets(supabaseClient(), unref(speciesId)),
    enabled: computed(() => unref(options.enabled) ?? true),
  });

export const useSaveWeightBrackets = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (args: { speciesId: string; rows: WeightBracketInput[] }) =>
      saveWeightBrackets(supabaseClient(), args.speciesId, args.rows),
    onSuccess: async () => {
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};
