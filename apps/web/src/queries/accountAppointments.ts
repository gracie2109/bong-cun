import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { sendMessageToast } from "@/lib/utils";
import { cancelErrorHint, cancelMyAppointment, listMyAppointments } from "@bongcun/supabase/account";
import type { AppointmentScope } from "@bongcun/core/account";
import { accountKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

/** One page of the customer's appointments; pass `false` for `enabled` while there is no customer record. */
export const useMyAppointments = (
  scope: MaybeRef<AppointmentScope>,
  page: MaybeRef<number>,
  pageSize: MaybeRef<number>,
  enabled: MaybeRef<boolean> = true
) =>
  useQuery({
    queryKey: computed(() => accountKeys.appointmentList(unref(scope), unref(page), unref(pageSize))),
    queryFn: () => listMyAppointments(supabaseClient(), unref(scope), unref(page), unref(pageSize)),
    enabled: computed(() => unref(enabled)),
    placeholderData: keepPreviousData,
  });

export const useCancelMyAppointment = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => cancelMyAppointment(supabaseClient(), id),
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: accountKeys.appointments() }),
        // the freed time shows again in the booking grid
        queryClient.invalidateQueries({ queryKey: ["spa", "web-slots"] }),
      ]);
      notifySuccess("update");
    },
    onError: async (error) => {
      const hint = cancelErrorHint(error);
      if (hint) sendMessageToast("fail", "update", "error", i18n.global.t(`client.appointments.errors.${hint}`));
      else notifyFailure("update", error);
      await queryClient.invalidateQueries({ queryKey: accountKeys.appointments() });
    },
  });
};
