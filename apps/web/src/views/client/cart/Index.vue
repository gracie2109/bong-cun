<template>
  <div class="shop-container min-h-[60vh] pb-10 pt-6 md:pt-10">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 class="shop-display text-3xl md:text-4xl">{{ $t("shop.cart.title") }}</h1>
        <p v-if="!isEmpty" class="mt-1 text-muted-foreground">{{ $t("shop.cart.items", { n: cart.lines.length }) }}</p>
      </div>
      <CheckoutSteps :current="0" />
    </div>

    <CartEmpty v-if="isEmpty" />
    <div v-else-if="loading" class="mt-8 grid gap-8 lg:grid-cols-[1fr_380px]" aria-hidden="true">
      <div class="shop-skeleton h-72 rounded-3xl" />
      <div class="shop-skeleton h-64 rounded-3xl" />
    </div>
    <EmptyState v-else-if="failed" tone="error" :title="$t('shop.cart.loadFailed')" :text="$t('client.catalog.errorHint')">
      <Button class="h-11 rounded-full px-6" @click="refresh()">{{ $t("shop.cart.retry") }}</Button>
    </EmptyState>

    <div v-else class="mt-8 grid items-start gap-8 lg:grid-cols-[1fr_380px]">
      <div>
        <TransitionGroup tag="ul" name="line" class="relative divide-y rounded-3xl border bg-white px-4 sm:px-6">
          <CartLineRow
            v-for="line in lines"
            :key="lineKey(line)"
            :line="line"
            @qty="(qty) => cart.setQty(lineKey(line), qty)"
            @remove="cart.remove(lineKey(line))"
          />
        </TransitionGroup>
        <div class="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm">
          <RouterLink :to="{ name: 'products' }" class="inline-flex items-center gap-1.5 font-semibold text-primary hover:underline">
            <ArrowLeft class="size-4" />{{ $t("shop.cart.continue") }}
          </RouterLink>
          <button type="button" class="text-muted-foreground hover:text-destructive hover:underline" @click="cart.clear()">
            {{ $t("shop.cart.clear") }}
          </button>
        </div>
      </div>
      <CartSummary
        :count="lines.length"
        :subtotal="subtotal"
        :has-issue="hasIssue"
        :in-store-only="inStoreOnly"
        :can-checkout="canCheckout"
        @checkout="goCheckout"
      />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { ArrowLeft } from "lucide-vue-next";
import CheckoutSteps from "@/components/shop/checkout/CheckoutSteps.vue";
import EmptyState from "@/components/shop/EmptyState.vue";
import { Button } from "@/components/ui/button";
import { useCartPage } from "@/composables/shop/useCartPage";
import { lineKey } from "@/utils/shop/cart";
import CartEmpty from "./components/CartEmpty.vue";
import CartLineRow from "./components/CartLineRow.vue";
import CartSummary from "./components/CartSummary.vue";

const { cart, lines, loading, failed, subtotal, hasIssue, inStoreOnly, isEmpty, canCheckout, goCheckout, refresh } =
  useCartPage();
</script>

<style scoped>
.line-leave-active {
  transition: opacity 200ms var(--ease-out), transform 200ms var(--ease-out);
  position: absolute;
  inset-inline: 1.5rem;
}
.line-leave-to {
  opacity: 0;
  transform: translateX(16px);
}
.line-move {
  transition: transform 260ms var(--ease-out);
}
</style>
