import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { sendMessageToast } from "@/lib/utils";
import {
  getMyProfile,
  hideMyPet,
  listMyPets,
  petErrorHint,
  profileErrorHint,
  saveMyPet,
  saveMyProfile,
} from "@/repositories/account";
import type { PetInput, ProfileInput } from "@/types/account";
import { accountKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

/** The signed-in customer's profile; pass `false` while signed out so nothing is requested. */
export const useMyProfile = (enabled: MaybeRef<boolean> = true) =>
  useQuery({
    queryKey: accountKeys.profile(),
    queryFn: () => getMyProfile(supabaseClient()),
    enabled: computed(() => unref(enabled)),
  });

export const useSaveMyProfile = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: ProfileInput) => saveMyProfile(supabaseClient(), input),
    onSuccess: async (profile) => {
      queryClient.setQueryData(accountKeys.profile(), profile);
      notifySuccess("update");
    },
    onError: (error) => {
      const hint = profileErrorHint(error);
      if (hint) sendMessageToast("fail", "update", "error", i18n.global.t(`client.account.errors.${hint}`));
      else notifyFailure("update", error);
    },
  });
};

/** The pets the signed-in customer owns; pass `false` while signed out. */
export const useMyPets = (enabled: MaybeRef<boolean> = true) =>
  useQuery({
    queryKey: accountKeys.pets(),
    queryFn: () => listMyPets(supabaseClient()),
    enabled: computed(() => unref(enabled)),
  });

const notifyPetFailure = (error: unknown, method: "create" | "update" | "delete") => {
  const hint = petErrorHint(error);
  if (hint) sendMessageToast("fail", method, "error", i18n.global.t(`client.pets.errors.${hint}`));
  else notifyFailure(method, error);
};

export const useSaveMyPet = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ input, id }: { input: PetInput; id: string }) => saveMyPet(supabaseClient(), input, id),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: accountKeys.pets() });
      notifySuccess("update");
    },
    onError: (error) => notifyPetFailure(error, "update"),
  });
};

export const useHideMyPet = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => hideMyPet(supabaseClient(), id),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: accountKeys.pets() });
      notifySuccess("delete");
    },
    onError: (error) => notifyPetFailure(error, "delete"),
  });
};
