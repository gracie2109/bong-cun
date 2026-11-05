import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { addTimeEntry, deleteTimeEntry, editTimeEntry, getAttendanceToday, getEntryHistory, markEntryReviewed } from "@bongcun/supabase/attendance";
import type { AddEntryInput, EditEntryInput } from "@bongcun/supabase/attendance";
import { attendanceKeys } from "@/queries/keys";
import { notifySuccess } from "@/queries/notify";
import { notifyAttendanceFailure } from "@/features/admin/attendance/queries/failure";

export const useAttendanceToday = (branchId: MaybeRef<string | undefined>, date: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.today(unref(branchId) ?? "", unref(date))),
    queryFn: () => getAttendanceToday(supabaseClient(), unref(branchId) as string, unref(date)),
    enabled: computed(() => !!unref(branchId)),
    refetchInterval: 60_000,
  });

export const useEntryHistory = (entryId: MaybeRef<string | null | undefined>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.history(unref(entryId) ?? "")),
    queryFn: () => getEntryHistory(supabaseClient(), unref(entryId) as string),
    enabled: computed(() => !!unref(entryId)),
  });

/** Every correction refreshes the board, the roster and the clock. */
const useEntryMutation = <Variables>(action: (variables: Variables) => Promise<unknown>, method: "create" | "update" | "delete") => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: action,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: attendanceKeys.all });
      notifySuccess(method);
    },
    onError: (error) => notifyAttendanceFailure(method, error),
  });
};

export const useAddEntry = () => useEntryMutation((input: AddEntryInput) => addTimeEntry(supabaseClient(), input), "create");
export const useEditEntry = () => useEntryMutation((input: EditEntryInput) => editTimeEntry(supabaseClient(), input), "update");
export const useDeleteEntry = () =>
  useEntryMutation((input: { id: string; reason: string }) => deleteTimeEntry(supabaseClient(), input.id, input.reason), "delete");
export const useReviewEntry = () => useEntryMutation((id: string) => markEntryReviewed(supabaseClient(), id), "update");
