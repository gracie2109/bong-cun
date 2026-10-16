<template>
  <aside class="rounded-3xl border bg-white p-5 shadow-card sm:p-6 lg:sticky lg:top-28 lg:self-start" :aria-labelledby="headingId">
    <h2 :id="headingId" class="text-lg font-bold tracking-tight">{{ $t("shop.cart.summary") }}</h2>

    <dl class="mt-4 space-y-3 text-sm">
      <div class="flex justify-between gap-3">
        <dt class="text-muted-foreground">{{ $t("shop.cart.subtotal") }}</dt>
        <dd class="font-semibold tabular-nums">{{ formatPrice(subtotal) }}</dd>
      </div>
      <div class="flex justify-between gap-3">
        <dt class="text-muted-foreground">{{ $t("shop.cart.shipping") }}</dt>
        <dd v-if="method === 'pickup'" class="font-semibold">{{ $t("shop.checkout.noShipping") }}</dd>
        <dd v-else-if="shipping.loading.value" class="text-muted-foreground">{{ $t("shop.checkout.quoting") }}</dd>
        <dd v-else-if="shipping.source.value === 'free'" class="font-semibold text-sage">{{ $t("shop.checkout.freeShip") }}</dd>
        <dd v-else class="text-right font-semibold tabular-nums">
          {{ formatPrice(shippingFee) }}
          <span v-if="shipping.estimated.value" class="block text-xs font-normal text-muted-foreground">
            {{ $t("shop.checkout.estimated") }}
          </span>
        </dd>
      </div>
      <div v-if="method === 'delivery' && shipping.leadtime.value" class="flex justify-between gap-3">
        <dt class="text-muted-foreground">{{ $t("shop.checkout.leadtime") }}</dt>
        <dd class="font-semibold">{{ formatDate(shipping.leadtime.value) }}</dd>
      </div>
    </dl>

    <div class="mt-4 flex items-baseline justify-between border-t border-dashed pt-4">
      <span class="font-semibold">{{ $t("shop.cart.total") }}</span>
      <span class="text-2xl font-extrabold tracking-tight tabular-nums">{{ formatPrice(total) }}</span>
    </div>

    <div class="mt-4 flex gap-3 rounded-2xl bg-secondary/70 p-3.5 text-sm">
      <Wallet class="mt-0.5 size-5 shrink-0 text-sage" aria-hidden="true" />
      <div>
        <p class="font-semibold">{{ $t(`shop.checkout.payment.${method}`) }}</p>
        <p class="text-muted-foreground">{{ $t(`shop.checkout.paymentHint.${method}`) }}</p>
      </div>
    </div>

    <div class="mt-4 space-y-1.5">
      <Label for="order-note">{{ $t("shop.checkout.note") }}</Label>
      <Textarea id="order-note" v-model="note" rows="2" maxlength="300" class="rounded-xl" :placeholder="$t('shop.checkout.notePlaceholder')" />
    </div>

    <p v-if="issue" class="mt-4 flex gap-2 rounded-xl bg-destructive/10 p-3 text-sm font-medium text-destructive" role="alert">
      <AlertCircle class="mt-0.5 size-4 shrink-0" aria-hidden="true" />{{ issue }}
    </p>

    <Button class="mt-5 h-[52px] w-full rounded-full text-base font-semibold" :disabled="blocked || placing" @click="$emit('submit')">
      <Loader2 v-if="placing" class="mr-2 size-4 animate-spin" />
      {{ $t("shop.checkout.place") }}
    </Button>
    <p class="mt-3 flex items-center justify-center gap-1.5 text-xs text-muted-foreground">
      <ShieldCheck class="size-4 text-sage" aria-hidden="true" />{{ $t("shop.cart.safeNote") }}
    </p>
  </aside>
</template>

<script lang="ts" setup>
import { AlertCircle, Loader2, ShieldCheck, Wallet } from "lucide-vue-next";
import { computed, useId } from "vue";
import { useI18n } from "vue-i18n";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { useShippingQuote } from "@/composables/shop/useShippingQuote";
import { formatPrice } from "@/lib/utils";
import type { DeliveryMethod } from "@bongcun/core/shop";
import { formatDate } from "@bongcun/core/shop";

const note = defineModel<string>("note", { required: true });
const props = defineProps<{
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

const { t } = useI18n();
const headingId = useId();

/** The one reason the order can't be placed yet, same priority as before. */
const issue = computed(() => {
  if (props.shipping.tooHeavy.value && props.method === "delivery") return t("shop.checkout.errors.too_heavy");
  if (props.overCodLimit) return t("shop.checkout.errors.cod_limit", { max: formatPrice(props.codMax) });
  if (props.hasIssue) return t("shop.cart.fixIssues");
  return "";
});
</script>
