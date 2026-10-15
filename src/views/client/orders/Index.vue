<template>
  <div class="shop-container min-h-[60vh] pb-12 pt-6 md:pt-10">
    <div v-if="loading" class="grid gap-8 lg:grid-cols-[1fr_380px]" aria-hidden="true">
      <div class="shop-skeleton h-72 rounded-3xl" />
      <div class="shop-skeleton h-64 rounded-3xl" />
    </div>
    <EmptyState v-else-if="notFound" :title="$t('shop.order.notFound')">
      <Button as-child class="h-11 rounded-full px-6"><RouterLink :to="{ name: 'home' }">{{ $t("shop.order.backHome") }}</RouterLink></Button>
    </EmptyState>
    <EmptyState v-else-if="failed || !order" tone="error" :title="$t('shop.order.loadFailed')" :text="$t('client.catalog.errorHint')">
      <Button class="h-11 rounded-full px-6" @click="retry()">{{ $t("shop.cart.retry") }}</Button>
    </EmptyState>

    <template v-else>
      <div v-if="placed" class="mb-8 flex flex-col gap-4 rounded-3xl bg-sage-soft p-5 sm:flex-row sm:items-center sm:justify-between sm:p-6" role="status">
        <div class="flex gap-4">
          <span class="grid size-12 shrink-0 place-content-center rounded-full bg-sage text-white"><PartyPopper class="size-6" /></span>
          <div>
            <p class="text-lg font-bold">{{ $t("shop.order.placedTitle") }}</p>
            <p class="text-sm text-muted-foreground">{{ $t(`shop.order.placedHint.${order.deliveryMethod}`) }}</p>
          </div>
        </div>
        <CheckoutSteps :current="2" />
      </div>

      <div class="mb-8 flex flex-wrap items-center gap-3">
        <h1 class="shop-display text-2xl md:text-3xl">{{ $t("shop.order.title", { code: order.code }) }}</h1>
        <OrderStatusBadge :status="order.status" />
        <span class="text-sm text-muted-foreground">{{ formatDateTime(order.placedAt) }}</span>
      </div>

      <div class="grid items-start gap-8 lg:grid-cols-[1fr_380px]">
        <div class="space-y-6">
          <OrderProgress :order="order" :steps="steps" />
          <OrderLines :lines="order.lines" />
        </div>
        <div class="space-y-4">
          <OrderInfo :order="order" :fee-went-up="feeWentUp" />
          <Button v-if="cancellable" variant="outline" class="h-11 w-full rounded-full text-destructive hover:text-destructive" @click="openCancel()">
            {{ $t("shop.order.cancel") }}
          </Button>
        </div>
      </div>

      <CancelOrderDialog v-model:open="cancelOpen" v-model:reason="cancelReason" :busy="cancelling" @confirm="confirmCancel()" />
    </template>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useRoute } from "vue-router";
import { PartyPopper } from "lucide-vue-next";
import CheckoutSteps from "@/components/shop/checkout/CheckoutSteps.vue";
import EmptyState from "@/components/shop/EmptyState.vue";
import { Button } from "@/components/ui/button";
import { useOrderPage } from "@/composables/shop/useOrderPage";
import { formatDateTime } from "@/utils/shop/order";
import CancelOrderDialog from "./components/CancelOrderDialog.vue";
import OrderInfo from "./components/OrderInfo.vue";
import OrderLines from "./components/OrderLines.vue";
import OrderProgress from "./components/OrderProgress.vue";
import OrderStatusBadge from "./components/OrderStatusBadge.vue";

const { order, loading, failed, notFound, retry, steps, cancellable, feeWentUp, cancelOpen, cancelReason, cancelling, openCancel, confirmCancel } =
  useOrderPage();
// "?placed=1" is only there right after checkout, for the thank-you note.
const placed = computed(() => useRoute().query.placed === "1");
</script>
