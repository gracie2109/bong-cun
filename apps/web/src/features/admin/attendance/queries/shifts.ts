import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getAttendanceRules, listShiftTemplates, saveAttendanceRules, saveShiftTemplate, setShiftTemplateActive } from "@bongcun/supabase/attendance";
import type { AttendanceRulesInput, ShiftTemplateInput } from "@bongcun/supabase/attendance";
import { attendanceKeys } from "@/queries/keys";
import { notifySuccess } from "@/queries/notify";
import { notifyAttendanceFailure } from "@/features/admin/attendance/queries/failure";

// ------------------------------------------------------------------- rules
export const useAttendanceRules = (branchId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.rules(unref(branchId) ?? "")),
    queryFn: () => getAttendanceRules(supabaseClient(), unref(branchId) as string),
    enabled: computed(() => !!unref(branchId)),
  });

/** Every attendance screen reads rules or templates, so a change refreshes them all. */
const useAttendanceMutation = <Variables, Result>(action: (variables: Variables) => Promise<Result>) => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: action,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: attendanceKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifyAttendanceFailure("update", error),
  });
};

export const useSaveAttendanceRules = () =>
  useAttendanceMutation(({ branchId, input }: { branchId: string; input: AttendanceRulesInput }) =>
    saveAttendanceRules(supabaseClient(), branchId, input));

// --------------------------------------------------------------- templates
export const useShiftTemplates = (branchId: MaybeRef<string | undefined>, includeInactive: MaybeRef<boolean> = false) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.templates(unref(branchId) ?? "", unref(includeInactive))),
    queryFn: () => listShiftTemplates(supabaseClient(), unref(branchId) as string, unref(includeInactive)),
    enabled: computed(() => !!unref(branchId)),
  });

export const useSaveShiftTemplate = () =>
  useAttendanceMutation(({ branchId, input }: { branchId: string; input: ShiftTemplateInput }) =>
    saveShiftTemplate(supabaseClient(), branchId, input));

export const useSetShiftTemplateActive = () =>
  useAttendanceMutation(({ id, active }: { id: string; active: boolean }) => setShiftTemplateActive(supabaseClient(), id, active));
