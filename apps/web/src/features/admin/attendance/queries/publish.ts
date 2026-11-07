import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { toast } from "vue-sonner";
import { computed, unref, type MaybeRef } from "vue";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import {
  assignToPreviousWeek,
  declareNoShifts,
  getRegistrationStatus,
  getWeekStatus,
  listRegistrationExemptions,
  listWeeksWithShifts,
  publishScheduleWeek,
  setRegistrationExemption,
  withdrawNoShifts,
} from "@bongcun/supabase/attendance";
import type { DeclareNoShiftsInput } from "@bongcun/supabase/attendance";
import { attendanceKeys } from "@/queries/keys";
import { notifySuccess } from "@/queries/notify";
import { notifyAttendanceFailure } from "@/features/admin/attendance/queries/failure";

/** Draft or published, for staff and managers alike. */
export const useWeekStatus = (branchId: MaybeRef<string | undefined>, monday: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.week(unref(branchId) ?? "", unref(monday))),
    queryFn: () => getWeekStatus(supabaseClient(), unref(branchId) as string, unref(monday)),
    enabled: computed(() => !!unref(branchId)),
  });

/** Who has not registered; `enabled` is off for people who cannot see it. */
export const useRegistrationStatus = (branchId: MaybeRef<string | undefined>, monday: MaybeRef<string>, enabled: MaybeRef<boolean> = true) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.registrationStatus(unref(branchId) ?? "", unref(monday))),
    queryFn: () => getRegistrationStatus(supabaseClient(), unref(branchId) as string, unref(monday)),
    enabled: computed(() => !!unref(branchId) && unref(enabled)),
  });

export const useRegistrationExemptions = (branchId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.exemptions(unref(branchId) ?? "")),
    queryFn: () => listRegistrationExemptions(supabaseClient(), unref(branchId) as string),
    enabled: computed(() => !!unref(branchId)),
  });

/** The future weeks that already have shifts; asked for when switching publishing on. */
export const useWeeksWithShifts = (branchId: MaybeRef<string | undefined>, enabled: MaybeRef<boolean> = true) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.weeksWithShifts(unref(branchId) ?? "")),
    queryFn: () => listWeeksWithShifts(supabaseClient(), unref(branchId) as string),
    enabled: computed(() => !!unref(branchId) && unref(enabled)),
  });

export const usePublishWeek = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (variables: { branchId: string; monday: string; rejectNote?: string }) =>
      publishScheduleWeek(supabaseClient(), variables.branchId, variables.monday, variables.rejectNote),
    onSuccess: async (result) => {
      await queryClient.invalidateQueries({ queryKey: attendanceKeys.all });
      toast.success(i18n.global.t("attendance.publish.done", { notified: result.notified, rejected: result.rejected }));
    },
    onError: (error) => notifyAttendanceFailure("update", error),
  });
};

export const useDeclareNoShifts = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: DeclareNoShiftsInput) => declareNoShifts(supabaseClient(), input),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: attendanceKeys.all });
      notifySuccess("create");
    },
    onError: (error) => notifyAttendanceFailure("create", error),
  });
};

export const useWithdrawNoShifts = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (variables: { branchId: string; monday: string }) => withdrawNoShifts(supabaseClient(), variables.branchId, variables.monday),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: attendanceKeys.all });
      notifySuccess("delete");
    },
    onError: (error) => notifyAttendanceFailure("delete", error),
  });
};

export const useSetExemption = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (variables: { branchId: string; userId: string; exempt: boolean; note?: string | null }) =>
      setRegistrationExemption(supabaseClient(), variables.branchId, variables.userId, variables.exempt, variables.note),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: attendanceKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifyAttendanceFailure("update", error),
  });
};

/** "Like last week" for one person who has not registered. */
export const useAssignLikeLastWeek = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (variables: { branchId: string; monday: string; userId: string }) =>
      assignToPreviousWeek(supabaseClient(), variables.branchId, variables.monday, variables.userId),
    onSuccess: async (result) => {
      await queryClient.invalidateQueries({ queryKey: attendanceKeys.all });
      toast.success(i18n.global.t("attendance.roster.copyDone", { copied: result.copied, skipped: result.skipped }));
    },
    onError: (error) => notifyAttendanceFailure("create", error),
  });
};
