import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabase } from "@/plugins/supabase";
import { createUserAsAdmin, listUsers, type CreateUserInput } from "@/repositories/users";
import { toPage, type PageParams } from "@/repositories/shared";
import { userKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

export const useUsersList = (page: MaybeRef<PageParams>, role?: string) =>
  useQuery({
    queryKey: computed(() => userKeys.list(toPage(unref(page)), role)),
    queryFn: () => listUsers(supabase, toPage(unref(page)), { role }),
    placeholderData: keepPreviousData,
  });

export const useCreateUser = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: CreateUserInput) => createUserAsAdmin(supabase, input),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: userKeys.all });
      notifySuccess("create");
    },
    onError: (error, input) => notifyFailure("create", error, input.displayName),
  });
};
