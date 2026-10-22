import { computed, ref, watch, type Ref } from "vue";
import type { LocationValue } from "@bongcun/core/locations";
import { useCommunes, useProvinces } from "../queries/useLocationQueries";
import { fromValue, pickProvince, pickWard, toOptions, toValue } from "../helpers/pickerState";
import type { PickerState } from "../types";

/**
 * Province -> commune choice. The model only ever receives a complete choice taken from the
 * server's lists; picking another province empties it until a commune of that province is picked.
 */
export const useLocationPicker = (model: Ref<LocationValue | null>) => {
  const state = ref<PickerState>(fromValue(model.value));

  // A value set from outside (editing another address) replaces what is on screen.
  watch(model, (next) => {
    if (toValue(state.value)?.wardCode !== next?.wardCode) state.value = fromValue(next);
  });

  const provinces = useProvinces();
  const communes = useCommunes(computed(() => state.value.province?.code ?? null));

  const provinceOptions = computed(() => toOptions(provinces.data.value ?? []));
  const wardOptions = computed(() => toOptions(communes.data.value ?? []));

  const choseProvince = (code: string) => {
    const unit = provinces.data.value?.find((item) => item.code === code);
    if (!unit) return;
    state.value = pickProvince(state.value, unit);
    model.value = toValue(state.value);
  };

  const choseWard = (code: string) => {
    const unit = communes.data.value?.find((item) => item.code === code);
    if (!unit) return;
    state.value = pickWard(state.value, unit);
    model.value = toValue(state.value);
  };

  return {
    state,
    provinceOptions,
    wardOptions,
    provincesLoading: provinces.isLoading,
    wardsLoading: communes.isFetching,
    provincesFailed: provinces.isError,
    wardsFailed: communes.isError,
    retryProvinces: () => provinces.refetch(),
    retryWards: () => communes.refetch(),
    choseProvince,
    choseWard,
  };
};
