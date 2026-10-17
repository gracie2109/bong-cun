import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { supabaseClient } from "@/lib/supabase";
import { getAdminSettings, getPublicSettings, saveSettings } from "@bongcun/supabase/shop";
import type { ShopSettings } from "@bongcun/core/shop";
import { shopKeys } from "@/queries/keys";
import { notifyFailure, notifySuccess } from "@/queries/notify";

/** Staff view of the shop settings (needs shop_orders: VIEW at the online branch). */
export const useShopSettings = () =>
  useQuery({ queryKey: shopKeys.settings(), queryFn: () => getAdminSettings(supabaseClient()) });

/** What the checkout reads; safe for anonymous visitors. */
export const useShopPublicSettings = () =>
  useQuery({
    queryKey: shopKeys.publicSettings(),
    queryFn: () => getPublicSettings(supabaseClient()),
    staleTime: 5 * 60 * 1000,
  });

export const useSaveShopSettings = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: ShopSettings) => saveSettings(supabaseClient(), input),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: shopKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};
