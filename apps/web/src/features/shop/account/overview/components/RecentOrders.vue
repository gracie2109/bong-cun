<template>
  <section class="space-y-3 rounded-xl border bg-white p-5">
    <div class="flex items-center justify-between">
      <h2 class="font-semibold">{{ $t("client.account.overview.recentOrders") }}</h2>
      <RouterLink :to="{ name: 'account-orders' }" class="text-sm font-semibold text-primary">
        {{ $t("client.account.overview.viewAll") }}
      </RouterLink>
    </div>
    <p v-if="loading" class="py-4 text-center text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <p v-else-if="orders.length === 0" class="py-4 text-center text-sm text-muted-foreground">{{ $t("shop.order.empty") }}</p>
    <ul v-else class="space-y-3">
      <OrderCard v-for="order in orders" :key="order.id" :order="order" />
    </ul>
  </section>
</template>

<script lang="ts" setup>
import type { ShopOrderSummary } from "@bongcun/core/shop";
import OrderCard from "../../orders/OrderCard.vue";

defineProps<{ orders: ShopOrderSummary[]; loading: boolean }>();
</script>
