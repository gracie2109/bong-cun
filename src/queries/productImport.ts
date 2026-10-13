import { useMutation, useQueryClient } from "@tanstack/vue-query";
import { supabaseClient } from "@/lib/supabase";
import { exportProducts, importProducts } from "@/repositories/productImport";
import type { ImportRow } from "@/views/admin/products/import/importTypes";
import { productBrandKeys, productCategoryKeys, productKeys } from "./keys";
import { notifyFailure } from "./notify";

export type ImportBatch = { rows: ImportRow[]; dryRun: boolean; fileName?: string };

/** Checks (dry run) or saves one batch of rows. A real import refreshes the product lists. */
export const useImportProducts = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ rows, dryRun, fileName }: ImportBatch) => importProducts(supabaseClient(), rows, dryRun, fileName),
    onSuccess: (_report, { dryRun }) => {
      if (dryRun) return;
      for (const queryKey of [productKeys.all, productCategoryKeys.all, productBrandKeys.all]) {
        void queryClient.invalidateQueries({ queryKey });
      }
    },
    onError: (error) => notifyFailure("create", error),
  });
};

export const useExportProducts = () =>
  useMutation({
    mutationFn: ({ limit, offset }: { limit: number; offset: number }) => exportProducts(supabaseClient(), limit, offset),
    onError: (error) => notifyFailure("get", error),
  });
