import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { supabaseClient } from "@/lib/supabase";
import {
  createRole,
  deleteRole,
  listRoles,
  updateRole,
  type RoleInput,
} from "@/repositories/roles";
import { roleKeys } from "./keys";
import { invalidateAccess } from "./invalidate";
import { notifyFailure, notifySuccess } from "./notify";

export const useRolesList = () =>
  useQuery({ queryKey: roleKeys.list(), queryFn: () => listRoles(supabaseClient()) });

export const useCreateRole = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: RoleInput) => createRole(supabaseClient(), input),
    onSuccess: async () => {
      await invalidateAccess(queryClient);
      notifySuccess("create");
    },
    onError: (error, input) => notifyFailure("create", error, input.name),
  });
};

export const useUpdateRole = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: RoleInput }) => updateRole(supabaseClient(), id, input),
    onSuccess: async () => {
      await invalidateAccess(queryClient);
      notifySuccess("update");
    },
    onError: (error, { input }) => notifyFailure("update", error, input.name),
  });
};

export const useDeleteRole = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deleteRole(supabaseClient(), id),
    onSuccess: async () => {
      await invalidateAccess(queryClient);
      notifySuccess("delete");
    },
    onError: (error) => notifyFailure("delete", error),
  });
};
