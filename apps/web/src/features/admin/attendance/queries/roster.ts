import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { toast } from "vue-sonner";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { assignShift, copyRosterWeek, getShiftRoster, removeShiftAssignment, updateShiftAssignment } from "@bongcun/supabase/attendance";
import type { AssignShiftInput, CopyWeekInput, UpdateShiftInput } from "@bongcun/supabase/attendance";
import { attendanceKeys } from "@/queries/keys";
import { notifySuccess } from "@/queries/notify";
import { notifyAttendanceFailure } from "@/features/admin/attendance/queries/failure";

export const useShiftRoster = (branchId: MaybeRef<string | undefined>, from: MaybeRef<string>, to: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.roster(unref(branchId) ?? "", unref(from), unref(to))),
    queryFn: () => getShiftRoster(supabaseClient(), unref(branchId) as string, unref(from), unref(to)),
    enabled: computed(() => !!unref(branchId)),
    placeholderData: keepPreviousData,
  });

/** Every roster change refreshes the grid; `onDone` gets what the call returned (a warning, counts...). */
const useRosterMutation = <Variables, Result>(
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

export const useAssignShift = () =>
  useRosterMutation(
    (input: AssignShiftInput) => assignShift(supabaseClient(), input),
    "create",
    (result) => {
      if (result.warning === "on_leave") toast.warning(i18n.global.t("attendance.roster.onLeaveWarning"));
    }
  );

export const useUpdateShift = () => useRosterMutation((input: UpdateShiftInput) => updateShiftAssignment(supabaseClient(), input), "update");

export const useRemoveShift = () =>
  useRosterMutation((input: { id: string; reason?: string | null }) => removeShiftAssignment(supabaseClient(), input.id, input.reason), "delete");

export const useCopyWeek = () =>
  useRosterMutation(
    (input: CopyWeekInput) => copyRosterWeek(supabaseClient(), input),
    "create",
    (result) => toast.success(i18n.global.t("attendance.roster.copyDone", { copied: result.copied, skipped: result.skipped }))
  );
