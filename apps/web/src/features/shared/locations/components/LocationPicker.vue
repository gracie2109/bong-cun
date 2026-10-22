<template>
  <div class="grid gap-3 sm:grid-cols-2">
    <div class="space-y-1.5">
      <Label>{{ $t("shop.location.province") }}<span v-if="required" class="text-red-600"> *</span></Label>
      <LocationCombobox
        :options="provinceOptions"
        :model-value="state.province?.code ?? null"
        :fallback-label="state.province?.fullName"
        :placeholder="$t('shop.location.pick')"
        :search-placeholder="$t('shop.location.searchProvince')"
        :empty-text="$t('shop.location.emptyProvince')"
        :disabled="disabled"
        :loading="provincesLoading"
        :failed="provincesFailed"
        @update:model-value="choseProvince"
        @retry="retryProvinces"
      />
    </div>
    <div class="space-y-1.5">
      <Label>{{ $t("shop.location.ward") }}<span v-if="required" class="text-red-600"> *</span></Label>
      <LocationCombobox
        :options="wardOptions"
        :model-value="state.ward?.code ?? null"
        :fallback-label="state.ward?.fullName"
        :placeholder="$t('shop.location.pick')"
        :search-placeholder="$t('shop.location.searchWard')"
        :empty-text="$t('shop.location.emptyWard')"
        :disabled="disabled || !state.province"
        :loading="wardsLoading"
        :failed="wardsFailed"
        @update:model-value="choseWard"
        @retry="retryWards"
      />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Label } from "@/components/ui/label";
import type { LocationValue } from "@bongcun/core/locations";
import { useLocationPicker } from "../composables/useLocationPicker";
import LocationCombobox from "./LocationCombobox.vue";

defineProps<{ disabled?: boolean; required?: boolean }>();

/** A complete province + commune, or null while one is missing. */
const model = defineModel<LocationValue | null>({ required: true });

const {
  state,
  provinceOptions,
  wardOptions,
  provincesLoading,
  wardsLoading,
  provincesFailed,
  wardsFailed,
  retryProvinces,
  retryWards,
  choseProvince,
  choseWard,
} = useLocationPicker(model);
</script>
