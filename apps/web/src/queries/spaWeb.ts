import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { sendMessageToast } from "@/lib/utils";
import { bookMyAppointment, bookingErrorHint, getSpaWebRules, listSpaWebSlots, quoteSpaWeb } from "@/repositories/spa";
import { DEFAULT_BOOKING_RULES, type BookingInput, type BookingItem } from "@bongcun/core/spa";
import { accountKeys, spaKeys } from "./keys";
import { notifyFailure } from "./notify";

/** The online booking limits; the defaults apply until the server answers. */
export const useSpaWebRules = () => {
  const query = useQuery({
    queryKey: spaKeys.webRules(),
    queryFn: () => getSpaWebRules(supabaseClient()),
    staleTime: 60 * 60 * 1000,
  });
  return computed(() => query.data.value ?? DEFAULT_BOOKING_RULES);
};

/** Slots of one day for a block of `minutes`; waits until all three are known. */
export const useSpaWebSlots = (branchId: MaybeRef<string | null>, date: MaybeRef<string>, minutes: MaybeRef<number>) =>
  useQuery({
    queryKey: computed(() => spaKeys.webSlots(unref(branchId) ?? "", unref(date), unref(minutes))),
    queryFn: () => listSpaWebSlots(supabaseClient(), unref(branchId) as string, unref(date), unref(minutes)),
    enabled: computed(() => Boolean(unref(branchId)) && Boolean(unref(date)) && unref(minutes) > 0),
    staleTime: 15 * 1000,
  });

export const useSpaWebQuote = (branchId: MaybeRef<string | null>, items: MaybeRef<BookingItem[]>) =>
  useQuery({
    queryKey: computed(() => spaKeys.webQuote(unref(branchId) ?? "", unref(items))),
    queryFn: () => quoteSpaWeb(supabaseClient(), unref(branchId) as string, unref(items)),
    enabled: computed(() => Boolean(unref(branchId)) && unref(items).length > 0),
  });

export const useBookAppointment = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: BookingInput) => bookMyAppointment(supabaseClient(), input),
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["spa", "web-slots"] }),
        queryClient.invalidateQueries({ queryKey: accountKeys.appointments() }),
      ]);
    },
    onError: async (error) => {
      const hint = bookingErrorHint(error);
      if (hint) sendMessageToast("fail", "create", "error", i18n.global.t(`client.booking.errors.${hint}`));
      else notifyFailure("create", error);
      // A full or stale slot: refresh the grid so the customer sees the real state.
      await queryClient.invalidateQueries({ queryKey: ["spa", "web-slots"] });
    },
  });
};
