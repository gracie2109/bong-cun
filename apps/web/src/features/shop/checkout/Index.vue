<template>
  <div class="shop-container min-h-[60vh] pb-12 pt-6 md:pt-10">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <h1 class="shop-display text-3xl md:text-4xl">{{ $t("shop.checkout.title") }}</h1>
      <CheckoutSteps :current="1" />
    </div>

    <div v-if="loading || settingsLoading" class="mt-8 grid gap-8 lg:grid-cols-[1fr_380px]" aria-hidden="true">
      <div class="space-y-6">
        <div class="shop-skeleton h-40 rounded-3xl" />
        <div class="shop-skeleton h-48 rounded-3xl" />
      </div>
      <div class="shop-skeleton h-80 rounded-3xl" />
    </div>
    <EmptyState v-else-if="isEmpty" :title="$t('shop.checkout.empty')">
      <template #icon><ShoppingBag class="size-10" /></template>
      <Button as-child class="h-11 rounded-full px-6">
        <RouterLink :to="{ name: 'products' }">{{ $t("shop.cart.continue") }}</RouterLink>
      </Button>
    </EmptyState>
    <EmptyState v-else-if="failed" tone="error" :title="$t('shop.cart.loadFailed')" :text="$t('client.catalog.errorHint')">
      <Button class="h-11 rounded-full px-6" @click="refresh()">{{ $t("shop.cart.retry") }}</Button>
    </EmptyState>
    <EmptyState v-else-if="!method" :title="$t('shop.checkout.noMethod')">
      <Button as-child variant="outline" class="h-11 rounded-full px-6">
        <RouterLink :to="{ name: 'cart' }">{{ $t("shop.checkout.backToCart") }}</RouterLink>
      </Button>
    </EmptyState>

    <div v-else class="mt-8 grid items-start gap-8 lg:grid-cols-[1fr_380px]">
      <div class="space-y-6">
        <CheckoutMethodPicker :methods="methods" :method="method" @update="setMethod" />
        <CheckoutAddress
          v-if="isDelivery"
          :address="address"
          :show-error="submitted && !!errors.address"
        />
        <CheckoutPickup
          v-else
          v-model:name="receiverName"
          v-model:phone="receiverPhone"
          :settings="settings"
          :errors="submitted ? errors : {}"
        />
        <CheckoutLines :lines="lines" />
      </div>
      <CheckoutSummary
        :method="method"
        :subtotal="subtotal"
        :shipping="shipping"
        :shipping-fee="shippingFee"
        :total="total"
        :over-cod-limit="overCodLimit"
        :cod-max="settings?.codMax ?? 0"
        :has-issue="hasIssue"
        :placing="placing"
        :blocked="blocked"
        v-model:note="note"
        @submit="submit"
      />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { ShoppingBag } from "lucide-vue-next";
import CheckoutSteps from "@/components/shop/checkout/CheckoutSteps.vue";
import EmptyState from "@/components/shop/EmptyState.vue";
import { Button } from "@/components/ui/button";
import { useCheckout } from "@/features/shop/checkout/composables/useCheckout";
import { computed } from "vue";
import CheckoutAddress from "./components/CheckoutAddress.vue";
import CheckoutLines from "./components/CheckoutLines.vue";
import CheckoutMethodPicker from "./components/CheckoutMethodPicker.vue";
import CheckoutPickup from "./components/CheckoutPickup.vue";
import CheckoutSummary from "./components/CheckoutSummary.vue";

const {
  lines,
  loading,
  settingsLoading,
  failed,
  refresh,
  settings,
  address,
  methods,
  method,
  isDelivery,
  setMethod,
  receiverName,
  receiverPhone,
  shipping,
  shippingFee,
  subtotal,
  total,
  overCodLimit,
  hasIssue,
  note,
  submitted,
  errors,
  blocked,
  placing,
  submit,
} = useCheckout();

const isEmpty = computed(() => lines.value.length === 0 && !loading.value);
</script>
