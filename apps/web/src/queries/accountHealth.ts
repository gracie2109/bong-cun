import { useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getMyPetHealth } from "@bongcun/supabase/account";
import { accountKeys } from "./keys";

/** The health book of one of the customer's pets. */
export const useMyPetHealth = (petId: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => accountKeys.petHealth(unref(petId))),
    queryFn: () => getMyPetHealth(supabaseClient(), unref(petId)),
    enabled: computed(() => !!unref(petId)),
  });
