import { keepPreviousData, useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { searchCustomers } from "@/repositories/customers";
import { customerKeys } from "./keys";

/** Customers matching the typed phone, name or email; empty until two characters are typed. */
export const useCustomerSearch = (text: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => customerKeys.search(unref(text).trim())),
    queryFn: () => searchCustomers(supabaseClient(), unref(text)),
    enabled: computed(() => unref(text).trim().length >= 2),
    placeholderData: keepPreviousData,
  });
