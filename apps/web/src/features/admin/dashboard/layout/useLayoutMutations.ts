import { useMutation, useQueryClient } from "@tanstack/vue-query";
import { resetLayout, saveLayout } from "@bongcun/supabase/dashboard";
import type { SavedItem } from "@bongcun/core/dashboard";
import { supabaseClient } from "@/lib/supabase";
import { dashboardKeys } from "@/queries/keys";

/** Saving and resetting a personal layout; both refresh the cached layout of every dashboard. */
export const useLayoutMutations = () => {
  const queryClient = useQueryClient();
  const refresh = () => queryClient.invalidateQueries({ queryKey: dashboardKeys.all });

  const save = useMutation({
    mutationFn: (input: { dashboardKey: string; items: SavedItem[]; expectedVersion: number }) =>
      saveLayout(supabaseClient(), input.dashboardKey, input.items, input.expectedVersion),
    onSuccess: refresh,
  });
  const reset = useMutation({
    mutationFn: (dashboardKey: string) => resetLayout(supabaseClient(), dashboardKey),
    onSuccess: refresh,
  });
  return { save, reset };
};
