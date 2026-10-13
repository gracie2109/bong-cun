<template>
  <section class="space-y-4 rounded-xl border bg-white p-5">
    <h2 class="text-lg font-semibold">{{ $t("shop.checkout.pickup") }}</h2>
    <div v-if="settings?.pickupAddress" class="rounded-lg bg-muted/40 p-3 text-sm">
      <p class="font-medium">{{ settings.pickupAddress }}</p>
      <p v-if="settings.pickupNote" class="mt-1 text-muted-foreground">{{ settings.pickupNote }}</p>
    </div>
    <div class="grid gap-4 sm:grid-cols-2">
      <div class="space-y-1.5">
        <Label for="pickup-name">{{ $t("shop.checkout.pickupName") }}</Label>
        <Input id="pickup-name" v-model="name" autocomplete="name" />
        <p v-if="errors.receiverName" class="text-xs text-red-600">{{ $t("petCare.common.required") }}</p>
      </div>
      <div class="space-y-1.5">
        <Label for="pickup-phone">{{ $t("shop.address.phone") }}</Label>
        <Input id="pickup-phone" v-model="phone" inputmode="tel" autocomplete="tel" />
        <p v-if="errors.receiverPhone" class="text-xs text-red-600">{{ $t("shop.address.errors.invalid_phone") }}</p>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { ShopPublicSettings } from "@/types/shop";
import type { CheckoutErrors } from "@/utils/shop/order";

const name = defineModel<string>("name", { required: true });
const phone = defineModel<string>("phone", { required: true });
defineProps<{ settings: ShopPublicSettings | undefined; errors: CheckoutErrors }>();
</script>
