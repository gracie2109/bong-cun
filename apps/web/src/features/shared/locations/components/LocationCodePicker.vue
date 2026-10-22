<template>
  <LocationPicker v-model="value" :disabled="disabled" :required="required" />
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import type { LocationValue } from "@bongcun/core/locations";
import { useLocationUnit } from "../queries/useLocationQueries";
import LocationPicker from "./LocationPicker.vue";

defineProps<{ disabled?: boolean; required?: boolean }>();

/** For forms that store only the commune code (the shop's warehouse): names are looked up for display. */
const code = defineModel<string | null>("code", { required: true });

const detail = useLocationUnit(code);

// What the shopper just picked is kept, so the picker does not blank while the detail loads.
const picked = ref<LocationValue | null>(null);

const value = computed<LocationValue | null>({
  get: () => {
    if (!code.value) return null;
    if (picked.value?.wardCode === code.value) return picked.value;
    const unit = detail.data.value;
    if (!unit?.province) return null;
    return { provinceCode: unit.province.code, provinceName: unit.province.fullName, wardCode: unit.code, wardName: unit.fullName };
  },
  set: (next) => {
    picked.value = next;
    code.value = next?.wardCode ?? null;
  },
});
</script>
