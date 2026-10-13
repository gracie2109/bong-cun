<template>
  <div class="container min-h-[60vh] py-8 md:px-12 lg:px-20">
    <p v-if="loading" class="py-16 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="notFound" class="py-16 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("shop.order.notFound") }}</p>
      <Button as-child variant="outline"><router-link :to="{ name: 'home' }">{{ $t("shop.order.backHome") }}</router-link></Button>
    </div>
    <div v-else-if="failed || !order" class="py-16 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("shop.order.loadFailed") }}</p>
      <Button variant="outline" @click="retry()">{{ $t("shop.cart.retry") }}</Button>
    </div>

    <template v-else>
      <div v-if="placed" class="mb-6 rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-emerald-900">
        <p class="font-semibold">{{ $t("shop.order.placedTitle") }}</p>
        <p class="text-sm">{{ $t(`shop.order.placedHint.${order.deliveryMethod}`) }}</p>
      </div>

      <div class="mb-6 flex flex-wrap items-center gap-3">
        <h1 class="text-2xl font-bold">{{ $t("shop.order.title", { code: order.code }) }}</h1>
        <OrderStatusBadge :status="order.status" />
        <span class="text-sm text-muted-foreground">{{ formatDateTime(order.placedAt) }}</span>
      </div>

      <div class="grid gap-6 lg:grid-cols-[1fr_24rem]">
        <div class="space-y-6">
          <OrderProgress :order="order" :steps="steps" />
          <OrderLines :lines="order.lines" />
        </div>
        <div class="space-y-4">
          <OrderInfo :order="order" :fee-went-up="feeWentUp" />
          <Button v-if="cancellable" variant="outline" class="w-full text-red-600" @click="openCancel()">
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
