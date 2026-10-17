import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getClinicOnly, setClinicOnly } from "@bongcun/supabase/products";
import { productKeys } from "@/queries/keys";
import { notifyFailure, notifySuccess } from "@/queries/notify";

export const useClinicOnly = (groupId: MaybeRef<string | null>) =>
  useQuery({
    queryKey: computed(() => [...productKeys.group(unref(groupId) ?? ""), "clinic-only"] as const),
    queryFn: () => getClinicOnly(supabaseClient(), unref(groupId) as string),
    enabled: computed(() => !!unref(groupId)),
  });

export const useSetClinicOnly = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (args: { groupId: string; value: boolean }) => setClinicOnly(supabaseClient(), args.groupId, args.value),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: productKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};
