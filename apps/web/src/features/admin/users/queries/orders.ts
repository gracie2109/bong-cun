import { keepPreviousData, useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { listOrdersByUserIds } from "@bongcun/supabase/customers";
import { orderKeys } from "@/queries/keys";

export const useOrdersByUsers = (userIds: MaybeRef<string[]>) =>
  useQuery({
    queryKey: computed(() => orderKeys.byUsers(unref(userIds))),
    queryFn: () => listOrdersByUserIds(supabaseClient(), unref(userIds)),
    enabled: computed(() => unref(userIds).length > 0),
    placeholderData: keepPreviousData,
  });
