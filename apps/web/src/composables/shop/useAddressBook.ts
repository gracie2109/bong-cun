import { computed, ref } from "vue";
import { useDeleteAddress, useMyAddresses, useSetDefaultAddress } from "@/queries/shopAddresses";
import { useAuthStore } from "@/stores";
import { MAX_ADDRESSES, type Address } from "@/types/shop";

/** The shopper's address list with delete and make-default; adding and editing is `useAddressForm`. */
export const useAddressBook = () => {
  const auth = useAuthStore();
  const query = useMyAddresses(computed(() => auth.isAuthenticated));
  const deleteMutation = useDeleteAddress();
  const defaultMutation = useSetDefaultAddress();

  const addresses = computed<Address[]>(() => query.data.value ?? []);
  const defaultAddress = computed(() => addresses.value.find((item) => item.isDefault) ?? addresses.value[0] ?? null);
  const atLimit = computed(() => addresses.value.length >= MAX_ADDRESSES);

  /** The address waiting for "are you sure" before it is deleted. */
  const toDelete = ref<Address | null>(null);
  const confirmDelete = async () => {
    const target = toDelete.value;
    toDelete.value = null;
    if (target) await deleteMutation.mutateAsync(target.id).catch(() => undefined);
  };

  return {
    addresses,
    defaultAddress,
    atLimit,
    loading: query.isLoading,
    toDelete,
    confirmDelete,
    makeDefault: (id: string) => defaultMutation.mutate(id),
    busy: computed(() => deleteMutation.isPending.value || defaultMutation.isPending.value),
  };
};
