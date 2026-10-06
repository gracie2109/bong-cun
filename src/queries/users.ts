import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  countUsers,
  createUserAsAdmin,
  listUsers,
  type CreateUserInput,
  type UserListFilter,
} from "@/repositories/users";
import { toPage, type PageParams } from "@/repositories/shared";
import { userKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

export const useUsersList = (page: MaybeRef<PageParams>, filter: MaybeRef<UserListFilter> = {}) =>
  useQuery({
    queryKey: computed(() => userKeys.list(toPage(unref(page)), { ...unref(filter) })),
    queryFn: () => listUsers(supabaseClient(), toPage(unref(page)), unref(filter)),
    placeholderData: keepPreviousData,
  });

export const useUsersCount = (filter: MaybeRef<UserListFilter>) =>
  useQuery({
    queryKey: computed(() => userKeys.count({ ...unref(filter) })),
    queryFn: () => countUsers(supabaseClient(), unref(filter)),
  });

export const useCreateUser = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: CreateUserInput) => createUserAsAdmin(supabaseClient(), input),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: userKeys.all });
      notifySuccess("create");
    },
    onError: (error, input) => notifyFailure("create", error, input.displayName),
  });
};
