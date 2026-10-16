<template>
  <CheckoutSection :step="2" :title="$t('shop.checkout.pickup')">
    <div v-if="settings?.pickupAddress" class="flex gap-3 rounded-2xl bg-sage-soft p-4 text-sm">
      <Store class="mt-0.5 size-5 shrink-0 text-sage" aria-hidden="true" />
      <div>
        <p class="font-semibold">{{ settings.pickupAddress }}</p>
        <p v-if="settings.pickupNote" class="mt-1 text-muted-foreground">{{ settings.pickupNote }}</p>
      </div>
    </div>
    <div class="mt-4 grid gap-4 sm:grid-cols-2">
      <div class="space-y-1.5">
        <Label for="pickup-name">{{ $t("shop.checkout.pickupName") }}</Label>
        <Input
          id="pickup-name"
          v-model="name"
          class="h-11 rounded-xl"
          autocomplete="name"
          :aria-invalid="!!errors.receiverName"
          :aria-describedby="errors.receiverName ? 'pickup-name-error' : undefined"
        />
        <p v-if="errors.receiverName" id="pickup-name-error" class="text-xs font-medium text-destructive">{{ $t("petCare.common.required") }}</p>
      </div>
      <div class="space-y-1.5">
        <Label for="pickup-phone">{{ $t("shop.address.phone") }}</Label>
        <Input
          id="pickup-phone"
          v-model="phone"
          class="h-11 rounded-xl"
          inputmode="tel"
          autocomplete="tel"
          :aria-invalid="!!errors.receiverPhone"
          :aria-describedby="errors.receiverPhone ? 'pickup-phone-error' : undefined"
        />
        <p v-if="errors.receiverPhone" id="pickup-phone-error" class="text-xs font-medium text-destructive">
          {{ $t("shop.address.errors.invalid_phone") }}
        </p>
      </div>
    </div>
  </CheckoutSection>
</template>

<script lang="ts" setup>
import { Store } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { ShopPublicSettings } from "@bongcun/core/shop";
import type { CheckoutErrors } from "@bongcun/core/shop";
import CheckoutSection from "./CheckoutSection.vue";

const name = defineModel<string>("name", { required: true });
const phone = defineModel<string>("phone", { required: true });
defineProps<{ settings: ShopPublicSettings | undefined; errors: CheckoutErrors }>();
</script>
