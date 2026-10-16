<template>
  <div class="grid gap-3 sm:grid-cols-3">
    <div class="space-y-1.5">
      <Label>{{ $t("shop.location.province") }}</Label>
      <Select :model-value="value(model.provinceId)" :disabled="disabled" @update:model-value="(v) => pickProvince(String(v))">
        <SelectTrigger><SelectValue :placeholder="$t('shop.location.pick')" /></SelectTrigger>
        <SelectContent side="bottom">
          <SelectItem v-for="item in provinceOptions" :key="item.value" :value="item.value">{{ item.label }}</SelectItem>
        </SelectContent>
      </Select>
    </div>
    <div class="space-y-1.5">
      <Label>{{ $t("shop.location.district") }}</Label>
      <Select
        :model-value="value(model.districtId)"
        :disabled="disabled || !model.provinceId"
        @update:model-value="(v) => pickDistrict(String(v))"
      >
        <SelectTrigger><SelectValue :placeholder="$t('shop.location.pick')" /></SelectTrigger>
        <SelectContent side="bottom">
          <SelectItem v-for="item in districtOptions" :key="item.value" :value="item.value">{{ item.label }}</SelectItem>
        </SelectContent>
      </Select>
    </div>
    <div class="space-y-1.5">
      <Label>{{ $t("shop.location.ward") }}</Label>
      <Select
        :model-value="model.wardCode ?? undefined"
        :disabled="disabled || !model.districtId"
        @update:model-value="(v) => pickWard(String(v))"
      >
        <SelectTrigger><SelectValue :placeholder="$t('shop.location.pick')" /></SelectTrigger>
        <SelectContent side="bottom">
          <SelectItem v-for="item in wardOptions" :key="item.value" :value="item.value">{{ item.label }}</SelectItem>
        </SelectContent>
      </Select>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useGhnLocationPicker } from "@/composables/shop/useGhnLocationPicker";
import type { GhnLocation } from "@bongcun/core/shop";

defineProps<{ disabled?: boolean }>();

/** Province, district and ward as GHN ids plus names. */
const model = defineModel<GhnLocation>({ required: true });

const { provinceOptions, districtOptions, wardOptions, pickProvince, pickDistrict, pickWard } =
  useGhnLocationPicker(model);

const value = (id: number | null) => (id ? String(id) : undefined);
</script>
