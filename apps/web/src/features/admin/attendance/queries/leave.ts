import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { toast } from "vue-sonner";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import {
  cancelLeave,
  decideLeave,
  getLeaveBalance,
  getMyLeave,
  getPendingLeaveCount,
  listLeaveRequests,
  requestLeave,
  requestLeaveFor,
  saveLeaveAllowance,
} from "@bongcun/supabase/attendance";
import type { DecideLeaveInput, LeaveFilter, LeaveResult, RequestLeaveForInput, RequestLeaveInput } from "@bongcun/supabase/attendance";
import { attendanceKeys } from "@/queries/keys";
import { notifySuccess } from "@/queries/notify";
import { notifyAttendanceFailure } from "@/features/admin/attendance/queries/failure";

const BADGE_REFRESH_MS = 60_000;

export const useLeaveList = (filter: MaybeRef<LeaveFilter>, page: MaybeRef<number>, pageSize: number) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.leaveList(unref(filter), unref(page))),
    queryFn: () => listLeaveRequests(supabaseClient(), unref(filter), unref(page), pageSize),
    placeholderData: keepPreviousData,
  });

export const useMyLeave = (year?: MaybeRef<number | undefined>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.myLeave(unref(year))),
    queryFn: () => getMyLeave(supabaseClient(), unref(year)),
  });

export const useLeaveBalance = (userId: MaybeRef<string | undefined>, year: MaybeRef<number>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.balance(unref(userId) ?? "", unref(year))),
    queryFn: () => getLeaveBalance(supabaseClient(), unref(userId) as string, unref(year)),
    enabled: computed(() => !!unref(userId)),
  });

/** Requests waiting for the caller to decide; `enabled` is off for staff who cannot decide. */
export const usePendingLeaveCount = (enabled: MaybeRef<boolean>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.pendingLeave(undefined)),
    queryFn: () => getPendingLeaveCount(supabaseClient()),
    enabled: computed(() => unref(enabled)),
    refetchInterval: BADGE_REFRESH_MS,
  });

const warn = (result: LeaveResult) => {
  if (result.warning === "over_allowance") toast.warning(i18n.global.t("attendance.leave.overAllowance"));
};

/** Every change refreshes the lists, the balances and the roster's leave colours. */
const useLeaveMutation = <Variables, Result>(
  action: (variables: Variables) => Promise<Result>,
  method: "create" | "update" | "delete",
  onDone?: (result: Result) => void
) => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: action,
    onSuccess: async (result) => {
      await queryClient.invalidateQueries({ queryKey: attendanceKeys.all });
      notifySuccess(method);
      onDone?.(result);
    },
    onError: (error) => notifyAttendanceFailure(method, error),
  });
};

export const useRequestLeave = () => useLeaveMutation((input: RequestLeaveInput) => requestLeave(supabaseClient(), input), "create", warn);
export const useRequestLeaveFor = () =>
  useLeaveMutation((input: RequestLeaveForInput) => requestLeaveFor(supabaseClient(), input), "create", warn);
export const useCancelLeave = () => useLeaveMutation((id: string) => cancelLeave(supabaseClient(), id), "delete");
export const useDecideLeave = () => useLeaveMutation((input: DecideLeaveInput) => decideLeave(supabaseClient(), input), "update", warn);
export const useSaveAllowance = () =>
  useLeaveMutation((input: { userId: string; year: number; days: number }) => saveLeaveAllowance(supabaseClient(), input.userId, input.year, input.days), "update");
