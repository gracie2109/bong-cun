import { useQuery } from "@tanstack/vue-query";
import { supabaseClient } from "@/lib/supabase";
import { getBoardingPublicCatalog } from "@/repositories/boarding";
import { boardingWebKeys } from "./keys";

/** The public price list of the pet hotel (first active branch). */
export const useBoardingPublicCatalog = () =>
  useQuery({
    queryKey: boardingWebKeys.catalog(),
    queryFn: () => getBoardingPublicCatalog(supabaseClient()),
  });
