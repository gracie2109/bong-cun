import { useQuery } from "@tanstack/vue-query";
import { boardingWebKeys } from "@/queries/keys";
import { usePublicApi } from "@/features/shared/public-api";

/** The public price list of the pet hotel (first active branch). */
export const useBoardingPublicCatalog = () => {
  const api = usePublicApi();
  return useQuery({
    queryKey: boardingWebKeys.catalog(),
    queryFn: () => api.boardingCatalog(),
  });
};
