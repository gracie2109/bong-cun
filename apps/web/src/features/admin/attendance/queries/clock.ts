import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { toast } from "vue-sonner";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { clockIn, clockOut, getClockStatus, getMySchedule } from "@bongcun/supabase/attendance";
import { attendanceErrorHint } from "@bongcun/supabase/attendance";
import type { ClockInInput } from "@bongcun/supabase/attendance";
import { attendanceKeys } from "@/queries/keys";
import { notifyAttendanceFailure } from "@/features/admin/attendance/queries/failure";

const REFRESH_MS = 60_000;

/** Who am I clocked in as, and which shifts could I join. Refreshed every minute and on focus. */
export const useClockStatus = () =>
  useQuery({
    queryKey: attendanceKeys.clock(),
    queryFn: () => getClockStatus(supabaseClient()),
    refetchInterval: REFRESH_MS,
    refetchOnWindowFocus: true,
  });

export const useClockIn = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: ClockInInput) => clockIn(supabaseClient(), input),
    onSuccess: async (result) => {
      await queryClient.invalidateQueries({ queryKey: attendanceKeys.all });
      toast.success(i18n.global.t("attendance.clock.clockedIn"));
      if (result.onLeave) toast.warning(i18n.global.t("attendance.clock.onLeaveWarning"));
      else if (result.lateMinutes > 0) toast.warning(i18n.global.t("attendance.clock.lateWarning", { minutes: result.lateMinutes }));
    },
    // `confirm_unscheduled` is a question for the dialog, not a failure.
    onError: (error) => {
      if (attendanceErrorHint(error) !== "confirm_unscheduled") notifyAttendanceFailure("create", error);
    },
  });
};

export const useClockOut = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (note?: string) => clockOut(supabaseClient(), note),
    onSuccess: async (result) => {
      await queryClient.invalidateQueries({ queryKey: attendanceKeys.all });
      toast.success(i18n.global.t("attendance.clock.clockedOut", { minutes: result.workedMinutes }));
    },
    onError: (error) => notifyAttendanceFailure("update", error),
  });
};

export const useMySchedule = (from: MaybeRef<string>, to: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.mine(unref(from), unref(to))),
    queryFn: () => getMySchedule(supabaseClient(), unref(from), unref(to)),
  });
