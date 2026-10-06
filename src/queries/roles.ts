import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { supabase } from "@/plugins/supabase";
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
  useQuery({ queryKey: roleKeys.list(), queryFn: () => listRoles(supabase) });

export const useCreateRole = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: RoleInput) => createRole(supabase, input),
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
    mutationFn: ({ id, input }: { id: string; input: RoleInput }) => updateRole(supabase, id, input),
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
    mutationFn: (id: string) => deleteRole(supabase, id),
    onSuccess: async () => {
      await invalidateAccess(queryClient);
      notifySuccess("delete");
    },
    onError: (error) => notifyFailure("delete", error),
  });
};
