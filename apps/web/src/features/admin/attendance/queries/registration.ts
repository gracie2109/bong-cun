import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  cancelShiftRequest,
  getMyShiftRequests,
  getRegistrationBoard,
  getRegistrationRules,
  saveRegistrationSettings,
  submitShiftRequests,
} from "@bongcun/supabase/attendance";
import type { RegistrationSettingsInput, SubmitRequestsInput } from "@bongcun/supabase/attendance";
import { attendanceKeys } from "@/queries/keys";
import { notifySuccess } from "@/queries/notify";
import { notifyAttendanceFailure } from "@/features/admin/attendance/queries/failure";

export const useRegistrationBoard = (branchId: MaybeRef<string | undefined>, monday: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.registration(unref(branchId) ?? "", unref(monday))),
    queryFn: () => getRegistrationBoard(supabaseClient(), unref(branchId) as string, unref(monday)),
    enabled: computed(() => !!unref(branchId)),
  });

export const useRegistrationRules = (branchId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.registrationRules(unref(branchId) ?? "")),
    queryFn: () => getRegistrationRules(supabaseClient(), unref(branchId) as string),
    enabled: computed(() => !!unref(branchId)),
  });

export const useMyShiftRequests = (from: MaybeRef<string>, to: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.myRequests(unref(from), unref(to))),
    queryFn: () => getMyShiftRequests(supabaseClient(), unref(from), unref(to)),
  });

export const useSaveRegistrationSettings = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (variables: { branchId: string; input: RegistrationSettingsInput }) =>
      saveRegistrationSettings(supabaseClient(), variables.branchId, variables.input),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: attendanceKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifyAttendanceFailure("update", error),
  });
};

/** Sending refreshes the board, "my requests" and the roster; the caller shows the result (skipped cells). */
export const useSubmitShiftRequests = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: SubmitRequestsInput) => submitShiftRequests(supabaseClient(), input),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: attendanceKeys.all }),
    onError: (error) => notifyAttendanceFailure("create", error),
  });
};

export const useCancelShiftRequest = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => cancelShiftRequest(supabaseClient(), id),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: attendanceKeys.all });
      notifySuccess("delete");
    },
    onError: (error) => notifyAttendanceFailure("delete", error),
  });
};
