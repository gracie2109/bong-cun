import { computed, ref, watch } from "vue";
import type { PetService, PetServiceInput } from "@/repositories/petServices";
import {
  DEFAULT_DURATION_MINUTES,
  DEFAULT_UNIT,
  MAX_DURATION_MINUTES,
  type ServicePricing,
} from "./serviceForm";

/** The service form: its fields, what is valid, and the input to save. */
export const useServiceForm = (isOpen: () => boolean, service: () => PetService | null) => {
  const name = ref("");
  const desc = ref("");
  const speciesIds = ref<string[]>([]);
  const type = ref<ServicePricing>("by_weight");
  const price = ref("");
  const duration = ref(String(DEFAULT_DURATION_MINUTES));
  const unit = ref(DEFAULT_UNIT);
  const isShow = ref(true);
  const submitted = ref(false);

  // Loads the service being edited, or a blank form, each time the sheet opens.
  watch(
    () => [isOpen(), service()],
    () => {
      if (!isOpen()) return;
      const current = service();
      name.value = current?.name ?? "";
      desc.value = current?.desc ?? "";
      speciesIds.value = current?.speciesIds ?? [];
      type.value = current?.type === "all" ? "all" : "by_weight";
      price.value = current?.generalPrice != null ? String(current.generalPrice) : "";
      duration.value = String(current?.duration[0] ?? DEFAULT_DURATION_MINUTES);
      unit.value = current?.unit ?? DEFAULT_UNIT;
      isShow.value = current?.isShow ?? true;
      submitted.value = false;
    },
    { immediate: true }
  );

  /** Species the service had that are no longer chosen, which also drops their prices. */
  const removedSpeciesCount = computed(
    () => (service()?.speciesIds ?? []).filter((id) => !speciesIds.value.includes(id)).length
  );

  const priceValid = computed(() => price.value !== "" && Number(price.value) >= 0);
  const durationValid = computed(() => {
    const minutes = Number(duration.value);
    return duration.value !== "" && minutes >= 0 && minutes <= MAX_DURATION_MINUTES;
  });

  /** The input to save, or null (showing the errors) when the form is not valid. */
  const toInput = (): PetServiceInput | null => {
    submitted.value = true;
    const valid =
      name.value.trim() &&
      speciesIds.value.length > 0 &&
      durationValid.value &&
      (type.value === "by_weight" || priceValid.value);
    if (!valid) return null;
    return {
      name: name.value.trim(),
      desc: desc.value.trim() || null,
      type: type.value,
      unit: unit.value,
      generalPrice: type.value === "all" ? Number(price.value) : null,
      duration: [Number(duration.value)],
      isShow: isShow.value,
      isActive: service()?.isActive ?? true,
      speciesIds: speciesIds.value,
    };
  };

  return {
    name,
    desc,
    speciesIds,
    type,
    price,
    duration,
    unit,
    isShow,
    submitted,
    removedSpeciesCount,
    priceValid,
    durationValid,
    toInput,
  };
};
