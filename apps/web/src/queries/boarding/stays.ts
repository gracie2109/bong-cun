import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  cancelBoardingStay,
  getBoardingBoard,
  getBoardingStay,
  getTypeAvailability,
  listBoardingStays,
  markBoardingNoShow,
  quoteBoardingStay,
  saveBoardingStay,
} from "@bongcun/supabase/boarding";
import { toPage, type PageParams } from "@bongcun/supabase/shared";
import type { StayFilter, StayInput } from "@bongcun/core/boarding";
import { boardingKeys } from "../keys";
import { notifySuccess } from "../notify";
import { notifyBoardingFailure } from "./failure";

// -------------------------------------------------------------------- stays
export const useBoardingStays = (
  branchId: MaybeRef<string | undefined>,
  page: MaybeRef<PageParams>,
  filter: MaybeRef<StayFilter>
) =>
  useQuery({
    queryKey: computed(() => boardingKeys.stays(unref(branchId) ?? "", toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listBoardingStays(supabaseClient(), unref(branchId) as string, toPage(unref(page)), { ...unref(filter) }),
    enabled: computed(() => !!unref(branchId)),
    placeholderData: keepPreviousData,
  });

export const useBoardingStay = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => boardingKeys.stay(unref(id) ?? "")),
    queryFn: () => getBoardingStay(supabaseClient(), unref(id) as string),
    enabled: computed(() => !!unref(id)),
  });

export const useSaveBoardingStay = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ branchId, input, id }: { branchId: string; input: StayInput; id?: string }) =>
      saveBoardingStay(supabaseClient(), branchId, input, id),
    onSuccess: async (_data, { id }) => {
      await queryClient.invalidateQueries({ queryKey: boardingKeys.all });
      notifySuccess(id ? "update" : "create");
    },
    onError: (error, { id }) => notifyBoardingFailure(id ? "update" : "create", error),
  });
};

export const useCancelBoardingStay = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason?: string }) => cancelBoardingStay(supabaseClient(), id, reason),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: boardingKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifyBoardingFailure("update", error),
  });
};

export const useMarkBoardingNoShow = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => markBoardingNoShow(supabaseClient(), id),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: boardingKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifyBoardingFailure("update", error),
  });
};

/** The price and the kennels a booking would get; refused bookings come back as `error`. */
export const useBoardingQuote = (
  branchId: MaybeRef<string | undefined>,
  stayId: MaybeRef<string | undefined>,
  input: MaybeRef<StayInput | null>
) =>
  useQuery({
    queryKey: computed(() => boardingKeys.quote(unref(branchId) ?? "", unref(stayId) ?? "", unref(input))),
    queryFn: () => quoteBoardingStay(supabaseClient(), unref(branchId) as string, unref(input) as StayInput, unref(stayId)),
    enabled: computed(() => !!unref(branchId) && !!unref(input)),
    retry: false,
    staleTime: 0,
    gcTime: 0,
  });

export const useTypeAvailability = (
  branchId: MaybeRef<string | undefined>,
  from: MaybeRef<string>,
  to: MaybeRef<string>
) =>
  useQuery({
    queryKey: computed(() => boardingKeys.availability(unref(branchId) ?? "", unref(from), unref(to))),
    queryFn: () => getTypeAvailability(supabaseClient(), unref(branchId) as string, unref(from), unref(to)),
    enabled: computed(() => !!unref(branchId) && !!unref(from) && !!unref(to) && unref(to) >= unref(from)),
    placeholderData: keepPreviousData,
  });

// -------------------------------------------------------------------- board
export const useBoardingBoard = (branchId: MaybeRef<string | undefined>, date: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => boardingKeys.board(unref(branchId) ?? "", unref(date))),
    queryFn: () => getBoardingBoard(supabaseClient(), unref(branchId) as string, unref(date)),
    enabled: computed(() => !!unref(branchId)),
    // The board stays open at the reception desk: pick up what the others book.
    refetchInterval: 60_000,
    refetchOnWindowFocus: true,
    placeholderData: keepPreviousData,
  });
