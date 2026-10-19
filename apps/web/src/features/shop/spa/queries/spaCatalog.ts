import { useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { spaKeys } from "@/queries/keys";
import { usePublicApi } from "@/features/shared/public-api";

/** The public price list for a branch; null asks for the first branch and the answer names it. */
export const useSpaPublicCatalog = (branchId: MaybeRef<string | null>) => {
  const api = usePublicApi();
  return useQuery({
    queryKey: computed(() => spaKeys.publicCatalog(unref(branchId))),
    queryFn: () => api.spaCatalog(unref(branchId)),
  });
};
