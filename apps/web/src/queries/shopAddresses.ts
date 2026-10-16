import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { sendMessageToast } from "@/lib/utils";
import {
  addressErrorHint,
  deleteMyAddress,
  listMyAddresses,
  saveMyAddress,
  setDefaultMyAddress,
} from "@bongcun/supabase/shop";
import type { AddressInput } from "@bongcun/core/shop";
import { shopKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

/** Failure toast that turns the address rules (limit, phone, place) into text. */
const notifyAddressFailure = (error: unknown) => {
  const hint = addressErrorHint(error);
  if (hint) sendMessageToast("fail", "update", "error", i18n.global.t(`shop.address.errors.${hint}`));
  else notifyFailure("update", error);
};

/** The signed-in shopper's addresses; pass `false` while signed out so nothing is requested. */
export const useMyAddresses = (enabled: MaybeRef<boolean> = true) =>
  useQuery({
    queryKey: shopKeys.addresses(),
    queryFn: () => listMyAddresses(supabaseClient()),
    enabled: computed(() => unref(enabled)),
  });

export const useSaveAddress = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: AddressInput) => saveMyAddress(supabaseClient(), input),
    onSuccess: async (_data, input) => {
      await queryClient.invalidateQueries({ queryKey: shopKeys.addresses() });
      notifySuccess(input.id ? "update" : "create");
    },
    onError: notifyAddressFailure,
  });
};

export const useSetDefaultAddress = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => setDefaultMyAddress(supabaseClient(), id),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: shopKeys.addresses() });
      notifySuccess("update");
    },
    onError: notifyAddressFailure,
  });
};

export const useDeleteAddress = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deleteMyAddress(supabaseClient(), id),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: shopKeys.addresses() });
      notifySuccess("delete");
    },
    onError: notifyAddressFailure,
  });
};
