import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { sendMessageToast } from "@/lib/utils";
import { linkCustomerAccount, linkErrorHint, searchUnlinkedAccounts } from "@bongcun/supabase/customers";
import { petProfileKeys } from "@/queries/keys";
import { notifyFailure, notifySuccess } from "@/queries/notify";

/** Web accounts without a customer record that match the text (2+ characters). */
export const useUnlinkedAccounts = (text: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => ["customer-accounts", "unlinked", unref(text).trim()] as const),
    queryFn: () => searchUnlinkedAccounts(supabaseClient(), unref(text)),
    enabled: computed(() => unref(text).trim().length >= 2),
  });

export const useLinkCustomerAccount = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ customerId, userId }: { customerId: string; userId: string }) =>
      linkCustomerAccount(supabaseClient(), customerId, userId),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: petProfileKeys.all });
      notifySuccess("update");
    },
    onError: (error) => {
      const hint = linkErrorHint(error);
      if (hint) sendMessageToast("fail", "update", "error", i18n.global.t(`petCare.pets.link.errors.${hint}`));
      else notifyFailure("update", error);
    },
  });
};
