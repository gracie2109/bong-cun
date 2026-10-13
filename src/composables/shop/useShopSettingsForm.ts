import { computed, reactive, ref, watch } from "vue";
import { useSaveShopSettings, useShopSettings } from "@/queries/shop";
import { useAuthStore } from "@/stores";
import { settingsErrors, toForm, toSettings, type SettingsForm } from "@/utils/shop/settingsForm";
import { emptyGhnLocation } from "@/types/shop";

const blankForm = (): SettingsForm => ({
  onlineBranchId: "",
  allowCod: true,
  allowPickup: true,
  codMax: "",
  defaultWeightG: "",
  flatShippingFee: "",
  freeShipFrom: "",
  from: emptyGhnLocation(),
  fromAddressText: "",
  pickupAddress: "",
  pickupNote: "",
});

/** State of the online shop settings screen: load, edit, validate, save. */
export const useShopSettingsForm = () => {
  const auth = useAuthStore();
  const query = useShopSettings();
  const mutation = useSaveShopSettings();

  const form = reactive<SettingsForm>(blankForm());
  const saved = ref("");
  const submitted = ref(false);

  // Start from what the database has; a refetch after saving resets the form.
  watch(
    () => query.data.value,
    (data) => {
      if (!data) return;
      Object.assign(form, toForm(data));
      saved.value = JSON.stringify(toForm(data));
    },
    { immediate: true }
  );

  const canEdit = computed(() => auth.can("shop_orders", "ALL"));
  const dirty = computed(() => JSON.stringify(form) !== saved.value);
  const errors = computed(() => settingsErrors(form));

  const save = async () => {
    submitted.value = true;
    if (!canEdit.value || errors.value.length) return;
    try {
      await mutation.mutateAsync(toSettings(form));
      submitted.value = false;
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return { form, query, canEdit, dirty, errors, submitted, saving: mutation.isPending, save };
};
