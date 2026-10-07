import { useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { searchCustomers } from "@/repositories/customers";
import { customerKeys } from "./keys";

/** Customers matching the typed phone or name; empty until two characters are typed. */
export const useCustomerSearch = (text: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => customerKeys.search(unref(text))),
    queryFn: () => searchCustomers(supabaseClient(), unref(text)),
    enabled: computed(() => unref(text).trim().length >= 2),
  });
