<template>
  <section class="rounded-xl border bg-white">
    <header class="border-b px-4 py-3">
      <h2 class="font-semibold">{{ $t("shop.settings.shipping") }}</h2>
      <p class="text-xs text-muted-foreground">{{ $t("shop.settings.shippingHint") }}</p>
    </header>
    <div class="space-y-4 p-4">
      <div class="grid gap-4 sm:grid-cols-3">
        <div class="space-y-1.5">
          <Label>{{ $t("shop.settings.defaultWeight") }}</Label>
          <Input v-model="form.defaultWeightG" inputmode="numeric" :disabled="disabled" />
          <p v-if="errors.includes('defaultWeight')" class="text-xs text-red-600">
            {{ $t("shop.settings.errors.defaultWeight") }}
          </p>
        </div>
        <div class="space-y-1.5">
          <Label>{{ $t("shop.settings.flatFee") }}</Label>
          <Input v-model="form.flatShippingFee" inputmode="numeric" :disabled="disabled" />
          <p class="text-xs text-muted-foreground">{{ $t("shop.settings.flatFeeHint") }}</p>
        </div>
        <div class="space-y-1.5">
          <Label>{{ $t("shop.settings.freeShipFrom") }}</Label>
          <Input v-model="form.freeShipFrom" inputmode="numeric" :disabled="disabled" />
          <p class="text-xs text-muted-foreground">{{ $t("shop.settings.freeShipHint") }}</p>
        </div>
      </div>

      <div class="space-y-2">
        <Label>{{ $t("shop.settings.fromAddress") }}</Label>
        <LocationCodePicker v-model:code="form.fromWardLocationCode" :disabled="disabled" />
        <Input v-model="form.fromStreet" :placeholder="$t('shop.settings.fromStreet')" :disabled="disabled" />
        <p v-if="form.from.districtId" class="text-xs text-muted-foreground">
          {{ $t("shop.settings.legacyGhn", { district: form.from.districtId, ward: form.from.wardCode }) }}
        </p>
        <p class="text-xs text-muted-foreground">{{ $t("shop.settings.fromAddressHint") }}</p>
        <ShippingTest :from="form.from" />
        <p v-if="errors.includes('fromAddress')" class="text-xs text-red-600">
          {{ $t("shop.settings.errors.fromAddress") }}
        </p>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { LocationCodePicker } from "@/features/shared/locations";
import type { SettingsForm } from "@bongcun/core/shop";
import ShippingTest from "./ShippingTest.vue";

defineProps<{ form: SettingsForm; errors: string[]; disabled: boolean }>();
</script>
