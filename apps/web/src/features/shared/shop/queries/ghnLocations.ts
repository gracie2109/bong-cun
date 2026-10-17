import { useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { getDistrict, getProvince, getWard } from "@/services/location.service";
import { ghnLocationKeys } from "@/queries/keys";

// GHN's administrative lists change rarely, so they are cached for the whole visit.
const STALE = Infinity;

export const useGhnProvinces = () =>
  useQuery({
    queryKey: ghnLocationKeys.provinces(),
    queryFn: async () => (await getProvince()) ?? [],
    staleTime: STALE,
  });

export const useGhnDistricts = (provinceId: MaybeRef<number | null>) =>
  useQuery({
    queryKey: computed(() => ghnLocationKeys.districts(unref(provinceId) ?? 0)),
    queryFn: async () => (await getDistrict(unref(provinceId) as number)) ?? [],
    enabled: computed(() => !!unref(provinceId)),
    staleTime: STALE,
  });

export const useGhnWards = (districtId: MaybeRef<number | null>) =>
  useQuery({
    queryKey: computed(() => ghnLocationKeys.wards(unref(districtId) ?? 0)),
    queryFn: async () => (await getWard(unref(districtId) as number)) ?? [],
    enabled: computed(() => !!unref(districtId)),
    staleTime: STALE,
  });
