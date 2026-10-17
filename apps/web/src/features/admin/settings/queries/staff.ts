import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { supabaseClient } from "@/lib/supabase";
import { listStaff, saveStaffAssignments, type StaffAssignment } from "@bongcun/supabase/users";
import { invalidateAccess } from "@/queries/invalidate";
import { staffKeys } from "@/queries/keys";
import { notifyFailure, notifySuccess } from "@/queries/notify";

export const useStaffList = () =>
  useQuery({ queryKey: staffKeys.list(), queryFn: () => listStaff(supabaseClient()) });

export const useSaveStaffAssignments = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ userId, assignments }: { userId: string; assignments: StaffAssignment[] }) =>
      saveStaffAssignments(supabaseClient(), userId, assignments),
    onSuccess: async () => {
      await invalidateAccess(queryClient);
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};
