import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { supabaseClient } from "@/lib/supabase";
import {
  createPermission,
  deletePermission,
  listPermissions,
  updatePermission,
  type PermissionInput,
} from "@/repositories/permissions";
import { permissionKeys } from "./keys";
import { invalidateAccess } from "./invalidate";
import { notifyFailure, notifySuccess } from "./notify";

export const usePermissionsList = () =>
  useQuery({ queryKey: permissionKeys.list(), queryFn: () => listPermissions(supabaseClient()) });

export const useCreatePermission = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: PermissionInput) => createPermission(supabaseClient(), input),
    onSuccess: async () => {
      await invalidateAccess(queryClient);
      notifySuccess("create");
    },
    onError: (error, input) => notifyFailure("create", error, input.name),
  });
};

export const useUpdatePermission = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: PermissionInput }) =>
      updatePermission(supabaseClient(), id, input),
    onSuccess: async () => {
      await invalidateAccess(queryClient);
      notifySuccess("update");
    },
    onError: (error, { input }) => notifyFailure("update", error, input.name),
  });
};

export const useDeletePermission = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deletePermission(supabaseClient(), id),
    onSuccess: async () => {
      await invalidateAccess(queryClient);
      notifySuccess("delete");
    },
    onError: (error) => notifyFailure("delete", error),
  });
};
