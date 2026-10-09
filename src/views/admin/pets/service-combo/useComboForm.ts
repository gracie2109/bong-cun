import { computed, ref, watch } from "vue";
import { formatPrice } from "@/lib/utils";
import { useAllPetServices } from "@/queries/petServices";
import type { PetCombo, PetComboInput } from "@/repositories/petCombos";
import { DEFAULT_MARK, STATUS_SELLING, STATUS_STOPPED } from "./comboStatus";

const dateInput = (iso: string | undefined): string => (iso ? iso.slice(0, 10) : "");

/** The combo form: its fields, what the chosen services add up to, and the input to save. */
export const useComboForm = (isOpen: () => boolean, combo: () => PetCombo | null) => {
  const servicesQuery = useAllPetServices();

  const name = ref("");
  const desc = ref("");
  const speciesIds = ref<string[]>([]);
  const serviceIds = ref<string[]>([]);
  const price = ref("");
  const duration = ref("0");
  const markAsId = ref(DEFAULT_MARK);
  const promoFrom = ref("");
  const promoTo = ref("");
  const sellable = ref(true);
  const submitted = ref(false);

  // Loads the combo being edited, or a blank form, each time the sheet opens.
  watch(
    () => [isOpen(), combo()],
    () => {
      if (!isOpen()) return;
      const current = combo();
      name.value = current?.name ?? "";
      desc.value = current?.desc ?? "";
      speciesIds.value = current?.speciesIds ?? [];
      serviceIds.value = current?.serviceIds ?? [];
      price.value = current?.price != null ? String(current.price) : "";
      duration.value = String(current?.duration[0] ?? 0);
      markAsId.value = current?.markAsId ?? DEFAULT_MARK;
      promoFrom.value = dateInput(current?.markTime[0]);
      promoTo.value = dateInput(current?.markTime[1]);
      sellable.value = (current?.status ?? STATUS_SELLING) === STATUS_SELLING;
      submitted.value = false;
    },
    { immediate: true }
  );

  // Only services offered for every chosen species can be bundled (the database checks this too).
  const serviceOptions = computed(() =>
    (servicesQuery.data.value ?? []).filter((service) =>
      speciesIds.value.every((id) => service.speciesIds.includes(id))
    )
  );
  const chosenServices = computed(() =>
    (servicesQuery.data.value ?? []).filter((service) => serviceIds.value.includes(service.id))
  );

  const originTotal = computed(() =>
    chosenServices.value.reduce((sum, service) => sum + (service.generalPrice ?? 0), 0)
  );
  const originPrice = computed(() => (originTotal.value > 0 ? formatPrice(originTotal.value) ?? "" : ""));
  const totalDuration = computed(() =>
    chosenServices.value.reduce((sum, service) => sum + (service.duration[0] ?? 0), 0)
  );
  const savings = computed(() => (price.value === "" ? 0 : Math.max(0, originTotal.value - Number(price.value))));
  const priceValid = computed(() => price.value !== "" && Number(price.value) >= 0);

  // Dropping a species drops the services that no longer fit all remaining species.
  watch(
    speciesIds,
    () => {
      const allowed = new Set(serviceOptions.value.map((service) => service.id));
      serviceIds.value = serviceIds.value.filter((id) => allowed.has(id));
    },
    { deep: true }
  );

  /** The input to save, or null (showing the errors) when the form is not valid. */
  const toInput = (): PetComboInput | null => {
    submitted.value = true;
    if (!name.value.trim() || speciesIds.value.length === 0 || serviceIds.value.length === 0 || !priceValid.value) {
      return null;
    }
    const hasWindow = promoFrom.value !== "" && promoTo.value !== "";
    return {
      name: name.value.trim(),
      desc: desc.value.trim() || null,
      origin_price: originTotal.value > 0 ? originTotal.value : null,
      price: Number(price.value),
      duration: [Number(duration.value || 0)],
      markAsId: markAsId.value,
      markTime: hasWindow ? [`${promoFrom.value}T00:00:00`, `${promoTo.value}T23:59:59`] : [],
      status: sellable.value ? STATUS_SELLING : STATUS_STOPPED,
      isActive: combo()?.isActive ?? true,
      speciesIds: [...speciesIds.value],
      serviceIds: [...serviceIds.value],
    };
  };

  return {
    name,
    desc,
    speciesIds,
    serviceIds,
    price,
    duration,
    markAsId,
    promoFrom,
    promoTo,
    sellable,
    submitted,
    serviceOptions,
    originPrice,
    totalDuration,
    savings,
    priceValid,
    toInput,
  };
};
