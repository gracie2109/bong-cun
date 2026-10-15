<template>
  <aside class="space-y-5 rounded-3xl border bg-white p-5 sm:p-6 lg:sticky lg:top-28">
    <h2 class="text-lg font-bold">{{ $t("shop.cart.summary") }}</h2>
    <FreeShipProgress :subtotal="subtotal" />
    <dl class="space-y-3 text-sm">
      <div class="flex justify-between gap-4">
        <dt class="text-muted-foreground">{{ $t("shop.cart.items", { n: count }) }}</dt>
        <dd class="font-medium tabular-nums">{{ formatPrice(subtotal) }}</dd>
      </div>
      <div class="flex justify-between gap-4">
        <dt class="text-muted-foreground">{{ $t("shop.cart.shipping") }}</dt>
        <dd class="text-right text-muted-foreground">{{ $t("shop.cart.shippingAtCheckout") }}</dd>
      </div>
    </dl>
    <div class="flex items-baseline justify-between border-t pt-4">
      <span class="font-semibold">{{ $t("shop.cart.total") }}</span>
      <span class="text-2xl font-extrabold tabular-nums">{{ formatPrice(subtotal) }}</span>
    </div>
    <p v-if="hasIssue" class="rounded-xl bg-destructive/10 px-3 py-2 text-sm text-destructive">{{ $t("shop.cart.fixIssues") }}</p>
    <p v-else-if="inStoreOnly" class="rounded-xl bg-amber-50 px-3 py-2 text-sm text-amber-800">{{ $t("shop.cart.inStoreOnlyNote") }}</p>
    <Button class="h-12 w-full rounded-full text-base" :disabled="!canCheckout" @click="emit('checkout')">
      {{ $t("shop.cart.checkout") }}<ArrowRight class="ml-2 size-5" />
    </Button>
    <p class="flex items-center justify-center gap-1.5 text-xs text-muted-foreground">
      <ShieldCheck class="size-4 text-sage" />{{ $t("shop.cart.safeNote") }}
    </p>
  </aside>
</template>

<script lang="ts" setup>
import { ArrowRight, ShieldCheck } from "lucide-vue-next";
import FreeShipProgress from "@/components/shop/checkout/FreeShipProgress.vue";
import { Button } from "@/components/ui/button";
import { formatPrice } from "@/lib/utils";

defineProps<{
  count: number;
  subtotal: number;
  hasIssue: boolean;
  inStoreOnly: boolean;
  canCheckout: boolean;
}>();
const emit = defineEmits<{ checkout: [] }>();
</script>
