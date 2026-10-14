import { useMutation, useQueryClient } from "@tanstack/vue-query";
import { supabaseClient } from "@/lib/supabase";
import { importPets } from "@/repositories/dataImports";
import type { PetImportRow } from "@/views/admin/pets/import/petsImportRow";
import { customerKeys, petProfileKeys } from "./keys";
import { notifyFailure } from "./notify";

export type PetImportBatch = { rows: PetImportRow[]; dryRun: boolean };

/** Checks (dry run) or saves one batch of customers and pets. A real import refreshes their lists. */
export const useImportPets = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ rows, dryRun }: PetImportBatch) => importPets(supabaseClient(), rows, dryRun),
    onSuccess: (_report, { dryRun }) => {
      if (dryRun) return;
      for (const queryKey of [petProfileKeys.all, customerKeys.all]) void queryClient.invalidateQueries({ queryKey });
    },
    onError: (error) => notifyFailure("create", error),
  });
};
