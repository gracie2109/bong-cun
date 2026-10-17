import { useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getPetHealthFlags } from "@bongcun/supabase/medical";
import { medicalKeys } from "@/queries/keys";

// Flags for the pets at a counter; any staff member may ask.
export const usePetHealthFlags = (petIds: MaybeRef<string[]>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.flags(unref(petIds))),
    queryFn: () => getPetHealthFlags(supabaseClient(), unref(petIds)),
    enabled: computed(() => unref(petIds).length > 0),
  });
