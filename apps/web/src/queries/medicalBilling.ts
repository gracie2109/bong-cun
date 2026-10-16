import { useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { listBillableMedical } from "@bongcun/supabase/medical";
import { medicalKeys } from "./keys";

// The signed visits of a customer that wait for payment in the POS.
export const useBillableMedical = (branchId: MaybeRef<string | undefined>, customerId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.billable(unref(branchId) ?? "", unref(customerId) ?? "")),
    queryFn: () => listBillableMedical(supabaseClient(), unref(branchId) as string, unref(customerId) as string),
    enabled: computed(() => !!unref(branchId) && !!unref(customerId)),
  });
