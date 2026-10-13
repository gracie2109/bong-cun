<template>
  <div class="container min-h-[60vh] py-8 md:px-12 lg:px-20">
    <h1 class="mb-6 text-2xl font-bold">{{ $t("shop.checkout.title") }}</h1>

    <p v-if="loading || settingsLoading" class="py-16 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="isEmpty" class="py-16 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("shop.checkout.empty") }}</p>
      <Button as-child variant="outline">
        <router-link :to="{ name: 'cart' }">{{ $t("shop.checkout.backToCart") }}</router-link>
      </Button>
    </div>
    <div v-else-if="failed" class="py-16 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("shop.cart.loadFailed") }}</p>
      <Button variant="outline" @click="refresh()">{{ $t("shop.cart.retry") }}</Button>
    </div>
    <p v-else-if="!method" class="py-16 text-center text-muted-foreground">{{ $t("shop.checkout.noMethod") }}</p>

    <div v-else class="grid gap-6 lg:grid-cols-[1fr_24rem]">
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
import { Button } from "@/components/ui/button";
import { useCheckout } from "@/composables/shop/useCheckout";
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
