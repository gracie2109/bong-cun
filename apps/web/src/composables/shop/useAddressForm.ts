import { computed, reactive, ref } from "vue";
import { useSaveAddress } from "@/queries/shopAddresses";
import type { Address } from "@/types/shop";
import {
  addressErrors,
  addressToForm,
  emptyAddressForm,
  formToInput,
  type AddressForm,
} from "@/utils/shop/address";

/**
 * The add / edit address dialog: its open state, form, validation and save.
 * `onSaved` gets the saved address (the checkout selects it).
 */
export const useAddressForm = (onSaved?: (address: Address) => void) => {
  const mutation = useSaveAddress();

  const open = ref(false);
  const submitted = ref(false);
  const form = reactive<AddressForm>(emptyAddressForm());
  const errors = computed(() => addressErrors(form));

  const openWith = (next: AddressForm) => {
    Object.assign(form, next);
    submitted.value = false;
    open.value = true;
  };

  /** `makeDefault` pre-ticks the default box, for the first address of a shopper. */
  const openNew = (makeDefault = false) => openWith({ ...emptyAddressForm(), isDefault: makeDefault });
  const openEdit = (address: Address) => openWith(addressToForm(address));

  const submit = async () => {
    submitted.value = true;
    if (Object.keys(errors.value).length > 0) return;
    try {
      const saved = await mutation.mutateAsync(formToInput(form));
      open.value = false;
      onSaved?.(saved);
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return { open, form, errors, submitted, saving: mutation.isPending, openNew, openEdit, submit };
};
