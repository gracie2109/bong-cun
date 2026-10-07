import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { supabaseClient } from "@/lib/supabase";
import { listStaff, saveStaffAssignments, type StaffAssignment } from "@/repositories/staff";
import { invalidateAccess } from "./invalidate";
import { staffKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

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
