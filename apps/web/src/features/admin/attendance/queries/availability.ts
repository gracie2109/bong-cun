import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getMyAvailability, getStaffAvailability, saveMyAvailability, saveStaffAvailability } from "@bongcun/supabase/attendance";
import type { AvailabilityItem } from "@bongcun/supabase/attendance";
import { attendanceKeys } from "@/queries/keys";
import { notifySuccess } from "@/queries/notify";
import { notifyAttendanceFailure } from "@/features/admin/attendance/queries/failure";

/** The caller's own pattern (`userId` empty) or a colleague's, for a manager who may see it. */
export const useAvailability = (userId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.availability(unref(userId) ?? "me")),
    queryFn: () => (unref(userId) ? getStaffAvailability(supabaseClient(), unref(userId) as string) : getMyAvailability(supabaseClient())),
  });

/** Saves the whole pattern; a `userId` means a manager editing for somebody else. */
export const useSaveAvailability = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { userId?: string; items: AvailabilityItem[] }) =>
      input.userId ? saveStaffAvailability(supabaseClient(), input.userId, input.items) : saveMyAvailability(supabaseClient(), input.items),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: attendanceKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifyAttendanceFailure("update", error),
  });
};
