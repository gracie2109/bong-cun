<template>
  <aside class="space-y-4 rounded-xl border bg-white p-5 lg:sticky lg:top-28">
    <h2 class="text-lg font-semibold">{{ $t("shop.cart.summary") }}</h2>
    <dl class="space-y-2 text-sm">
      <div class="flex justify-between">
        <dt class="text-muted-foreground">{{ $t("shop.cart.items", { n: count }) }}</dt>
        <dd class="font-medium">{{ formatPrice(subtotal) }}</dd>
      </div>
      <div class="flex justify-between">
        <dt class="text-muted-foreground">{{ $t("shop.cart.shipping") }}</dt>
        <dd class="text-muted-foreground">{{ $t("shop.cart.shippingAtCheckout") }}</dd>
      </div>
    </dl>
    <div class="flex items-baseline justify-between border-t pt-4">
      <span class="font-semibold">{{ $t("shop.cart.total") }}</span>
      <span class="text-2xl font-bold text-primary">{{ formatPrice(subtotal) }}</span>
    </div>
    <p v-if="hasIssue" class="text-sm text-red-600">{{ $t("shop.cart.fixIssues") }}</p>
    <p v-else-if="inStoreOnly" class="text-sm text-amber-700">{{ $t("shop.cart.inStoreOnlyNote") }}</p>
    <Button class="h-12 w-full text-base" :disabled="!canCheckout" @click="$emit('checkout')">
      {{ $t("shop.cart.checkout") }}
    </Button>
    <button type="button" class="w-full text-center text-sm text-muted-foreground hover:underline" @click="$emit('clear')">
      {{ $t("shop.cart.clear") }}
    </button>
  </aside>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { formatPrice } from "@/lib/utils";

defineProps<{
  count: number;
  subtotal: number;
  hasIssue: boolean;
  inStoreOnly: boolean;
  canCheckout: boolean;
}>();
defineEmits<{ checkout: []; clear: [] }>();
</script>
