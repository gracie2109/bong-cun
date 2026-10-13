<template>
  <aside class="space-y-4 rounded-xl border bg-white p-5 lg:sticky lg:top-28 lg:self-start">
    <h2 class="text-lg font-semibold">{{ $t("shop.cart.summary") }}</h2>

    <dl class="space-y-2 text-sm">
      <div class="flex justify-between">
        <dt class="text-muted-foreground">{{ $t("shop.cart.subtotal") }}</dt>
        <dd class="font-medium">{{ formatPrice(subtotal) }}</dd>
      </div>
      <div class="flex justify-between gap-3">
        <dt class="text-muted-foreground">{{ $t("shop.cart.shipping") }}</dt>
        <dd v-if="method === 'pickup'" class="font-medium">{{ $t("shop.checkout.noShipping") }}</dd>
        <dd v-else-if="shipping.loading.value" class="text-muted-foreground">{{ $t("shop.checkout.quoting") }}</dd>
        <dd v-else-if="shipping.source.value === 'free'" class="font-medium text-emerald-700">{{ $t("shop.checkout.freeShip") }}</dd>
        <dd v-else class="text-right font-medium">
          {{ formatPrice(shippingFee) }}
          <span v-if="shipping.estimated.value" class="block text-xs font-normal text-muted-foreground">
            {{ $t("shop.checkout.estimated") }}
          </span>
        </dd>
      </div>
      <div v-if="method === 'delivery' && shipping.leadtime.value" class="flex justify-between gap-3">
        <dt class="text-muted-foreground">{{ $t("shop.checkout.leadtime") }}</dt>
        <dd class="font-medium">{{ formatDate(shipping.leadtime.value) }}</dd>
      </div>
    </dl>

    <div class="flex items-baseline justify-between border-t pt-4">
      <span class="font-semibold">{{ $t("shop.cart.total") }}</span>
      <span class="text-2xl font-bold text-primary">{{ formatPrice(total) }}</span>
    </div>

    <div class="rounded-lg bg-muted/40 p-3 text-sm">
      <p class="font-medium">{{ $t(`shop.checkout.payment.${method}`) }}</p>
      <p class="text-muted-foreground">{{ $t(`shop.checkout.paymentHint.${method}`) }}</p>
    </div>

    <div class="space-y-1.5">
      <Label for="order-note">{{ $t("shop.checkout.note") }}</Label>
      <Textarea id="order-note" v-model="note" rows="2" maxlength="300" :placeholder="$t('shop.checkout.notePlaceholder')" />
    </div>

    <p v-if="shipping.tooHeavy.value && method === 'delivery'" class="text-sm text-red-600">{{ $t("shop.checkout.errors.too_heavy") }}</p>
    <p v-else-if="overCodLimit" class="text-sm text-red-600">{{ $t("shop.checkout.errors.cod_limit", { max: formatPrice(codMax) }) }}</p>
    <p v-else-if="hasIssue" class="text-sm text-red-600">{{ $t("shop.cart.fixIssues") }}</p>

    <Button class="h-12 w-full text-base" :disabled="blocked || placing" @click="$emit('submit')">
      <Loader2 v-if="placing" class="mr-2 size-4 animate-spin" />
      {{ $t("shop.checkout.place") }}
    </Button>
  </aside>
</template>

<script lang="ts" setup>
import { Loader2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { useShippingQuote } from "@/composables/shop/useShippingQuote";
import { formatPrice } from "@/lib/utils";
import type { DeliveryMethod } from "@/types/shopOrder";
import { formatDate } from "@/utils/shop/order";

const note = defineModel<string>("note", { required: true });
defineProps<{
  method: DeliveryMethod;
  subtotal: number;
  shipping: ReturnType<typeof useShippingQuote>;
  shippingFee: number;
  total: number;
  overCodLimit: boolean;
  codMax: number;
  hasIssue: boolean;
  placing: boolean;
  blocked: boolean;
}>();
defineEmits<{ submit: [] }>();
</script>
