import { useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getSpaPublicCatalog } from "@bongcun/supabase/spa";
import { spaKeys } from "./keys";

/** The public price list for a branch (null = shared prices only). */
export const useSpaPublicCatalog = (branchId: MaybeRef<string | null>) =>
  useQuery({
    queryKey: computed(() => spaKeys.publicCatalog(unref(branchId))),
    queryFn: () => getSpaPublicCatalog(supabaseClient(), unref(branchId)),
  });
