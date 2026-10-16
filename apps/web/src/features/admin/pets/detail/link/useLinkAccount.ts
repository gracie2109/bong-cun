import { refDebounced } from "@vueuse/core";
import { computed, ref, watch } from "vue";
import { useLinkCustomerAccount, useUnlinkedAccounts } from "@/queries/customerAccounts";
import { SEARCH_DEBOUNCE_MS } from "@/lib/listing";

/** Link one counter customer to a web account: search the accounts without a customer record, pick, save. */
export const useLinkAccount = (customerId: () => string, onLinked: () => void) => {
  const input = ref("");
  const text = refDebounced(input, SEARCH_DEBOUNCE_MS);
  const accounts = useUnlinkedAccounts(text);
  const mutation = useLinkCustomerAccount();
  const selectedId = ref<string | null>(null);

  watch(text, () => (selectedId.value = null));

  const submit = async () => {
    if (!selectedId.value) return;
    try {
      await mutation.mutateAsync({ customerId: customerId(), userId: selectedId.value });
      onLinked();
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return {
    input,
    selectedId,
    results: computed(() => accounts.data.value ?? []),
    searching: computed(() => input.value.trim().length >= 2 && accounts.isFetching.value),
    searched: computed(() => text.value.trim().length >= 2 && !accounts.isFetching.value),
    saving: mutation.isPending,
    submit,
  };
};
