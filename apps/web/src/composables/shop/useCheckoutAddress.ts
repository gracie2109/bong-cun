import { computed, ref } from "vue";
import { useMyAddresses } from "@/queries/shopAddresses";
import { useAuthStore } from "@/stores";
import type { Address } from "@/types/shop";
import { useAddressForm } from "./useAddressForm";

/**
 * The delivery address of the checkout: the shopper's default one until they pick another or add
 * a new one (a new address is selected as soon as it is saved).
 */
export const useCheckoutAddress = () => {
  const auth = useAuthStore();
  const query = useMyAddresses(computed(() => auth.isAuthenticated));

  const addresses = computed<Address[]>(() => query.data.value ?? []);
  const pickedId = ref<string | null>(null);
  const selected = computed<Address | null>(
    () =>
      addresses.value.find((item) => item.id === pickedId.value) ??
      addresses.value.find((item) => item.isDefault) ??
      addresses.value[0] ??
      null
  );

  const pickerOpen = ref(false);
  const form = useAddressForm((saved) => {
    pickedId.value = saved.id;
    pickerOpen.value = false;
  });

  const pick = (id: string) => {
    pickedId.value = id;
    pickerOpen.value = false;
  };

  return {
    addresses,
    selected,
    loading: query.isLoading,
    pickerOpen,
    form,
    pick,
    /** The first address of an account becomes its default. */
    addNew: () => form.openNew(addresses.value.length === 0),
    edit: (address: Address) => form.openEdit(address),
  };
};
