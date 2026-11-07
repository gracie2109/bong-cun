import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { decideShiftRequests, getPendingShiftRequestCount, listShiftRequests } from "@bongcun/supabase/attendance";
import type { DecideRequestsInput, ShiftRequestFilter } from "@bongcun/supabase/attendance";
import { attendanceKeys } from "@/queries/keys";
import { notifyAttendanceFailure } from "@/features/admin/attendance/queries/failure";

const BADGE_REFRESH_MS = 60_000;

export const useShiftRequestList = (filter: MaybeRef<ShiftRequestFilter>, page: MaybeRef<number>, pageSize: number) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.requestList(unref(filter), unref(page))),
    queryFn: () => listShiftRequests(supabaseClient(), unref(filter), unref(page), pageSize),
    placeholderData: keepPreviousData,
  });

/** Requests waiting for the caller to decide; `enabled` is off for staff who cannot decide. */
export const usePendingShiftRequestCount = (enabled: MaybeRef<boolean>, branchId?: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.pendingRequests(unref(branchId))),
    queryFn: () => getPendingShiftRequestCount(supabaseClient(), unref(branchId)),
    enabled: computed(() => unref(enabled)),
    refetchInterval: BADGE_REFRESH_MS,
  });

/** Deciding refreshes the lists, the roster and the badge; the caller shows which ones failed. */
export const useDecideShiftRequests = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: DecideRequestsInput) => decideShiftRequests(supabaseClient(), input),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: attendanceKeys.all }),
    onError: (error) => notifyAttendanceFailure("update", error),
  });
};
