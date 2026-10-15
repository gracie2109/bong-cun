import { keepPreviousData, useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getMyBoardingStay, listMyBoardingStays } from "@/repositories/account";
import type { BoardingScope } from "@/types/account";
import { accountKeys } from "./keys";

/** One page of the customer's boarding stays; pass `false` for `enabled` while there is no customer record. */
export const useMyBoardingStays = (
  scope: MaybeRef<BoardingScope>,
  page: MaybeRef<number>,
  pageSize: number,
  enabled: MaybeRef<boolean> = true
) =>
  useQuery({
    queryKey: computed(() => accountKeys.boardingList(unref(scope), unref(page), pageSize)),
    queryFn: () => listMyBoardingStays(supabaseClient(), unref(scope), unref(page), pageSize),
    enabled: computed(() => unref(enabled)),
    placeholderData: keepPreviousData,
  });

export const useMyBoardingStay = (id: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => accountKeys.boardingStay(unref(id))),
    queryFn: () => getMyBoardingStay(supabaseClient(), unref(id)),
    enabled: computed(() => !!unref(id)),
  });
