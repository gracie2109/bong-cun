import { keepPreviousData, useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getBoardingTimeline, moveBoardingPet } from "@bongcun/supabase/boarding";
import { boardingKeys } from "../keys";
import { useBoardingAction } from "./action";

// ---------------------------------------------------------------- calendar
export const useBoardingTimeline = (branchId: MaybeRef<string | undefined>, from: MaybeRef<string>, days: number) =>
  useQuery({
    queryKey: computed(() => boardingKeys.timeline(unref(branchId) ?? "", unref(from), days)),
    queryFn: () => getBoardingTimeline(supabaseClient(), unref(branchId) as string, unref(from), days),
    enabled: computed(() => !!unref(branchId)),
    placeholderData: keepPreviousData,
  });

export const useMoveBoardingPet = () =>
  useBoardingAction(({ stayPetId, kennelId }: { stayPetId: string; kennelId: string }) =>
    moveBoardingPet(supabaseClient(), stayPetId, kennelId));
