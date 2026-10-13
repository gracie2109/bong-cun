<template>
  <div class="container min-h-[60vh] py-8 md:px-12 lg:px-20">
    <h1 class="mb-6 text-2xl font-bold">{{ $t("shop.cart.title") }}</h1>

    <CartEmpty v-if="isEmpty" />
    <p v-else-if="loading" class="py-16 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="failed" class="py-16 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("shop.cart.loadFailed") }}</p>
      <Button variant="outline" @click="refresh()">{{ $t("shop.cart.retry") }}</Button>
    </div>

    <div v-else class="grid gap-6 lg:grid-cols-[1fr_22rem]">
      <ul class="space-y-3">
        <CartLineRow
          v-for="line in lines"
          :key="lineKey(line)"
          :line="line"
          @qty="(qty) => cart.setQty(lineKey(line), qty)"
          @remove="cart.remove(lineKey(line))"
        />
      </ul>
      <CartSummary
        :count="lines.length"
        :subtotal="subtotal"
        :has-issue="hasIssue"
        :in-store-only="inStoreOnly"
        :can-checkout="canCheckout"
        @checkout="goCheckout"
        @clear="cart.clear()"
      />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { useCartPage } from "@/composables/shop/useCartPage";
import { lineKey } from "@/utils/shop/cart";
import CartEmpty from "./components/CartEmpty.vue";
import CartLineRow from "./components/CartLineRow.vue";
import CartSummary from "./components/CartSummary.vue";

const { cart, lines, loading, failed, subtotal, hasIssue, inStoreOnly, isEmpty, canCheckout, goCheckout, refresh } =
  useCartPage();
</script>
