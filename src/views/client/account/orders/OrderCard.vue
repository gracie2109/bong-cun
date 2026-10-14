<template>
  <li>
    <router-link
      :to="{ name: 'order-detail', params: { code: order.code } }"
      class="flex gap-3 rounded-xl border bg-white p-3 transition hover:border-primary/50 sm:gap-4 sm:p-4"
    >
      <div class="size-16 shrink-0 overflow-hidden rounded-lg bg-muted/40">
        <img v-if="order.firstImage" :src="order.firstImage" alt="" class="size-full object-cover" loading="lazy" />
        <div v-else class="grid size-full place-content-center"><ImageIcon class="size-6 text-muted-foreground" /></div>
      </div>
      <div class="min-w-0 flex-1 space-y-1">
        <div class="flex flex-wrap items-center gap-2">
          <p class="font-semibold">{{ order.code }}</p>
          <OrderStatusBadge :status="order.status" />
        </div>
        <p class="line-clamp-1 text-sm">
          {{ order.firstName }}<template v-if="order.lineCount > 1"> · {{ $t("shop.order.more", { n: order.lineCount - 1 }) }}</template>
        </p>
        <p class="text-xs text-muted-foreground">
          {{ formatDateTime(order.placedAt) }} · {{ $t(`shop.checkout.methods.${order.deliveryMethod}`) }}
        </p>
      </div>
      <p class="shrink-0 self-center font-bold text-primary">{{ formatPrice(order.total) }}</p>
    </router-link>
  </li>
</template>

<script lang="ts" setup>
import { Image as ImageIcon } from "lucide-vue-next";
import { formatPrice } from "@/lib/utils";
import type { ShopOrderSummary } from "@/types/shopOrder";
import { formatDateTime } from "@/utils/shop/order";
import OrderStatusBadge from "@/views/client/orders/components/OrderStatusBadge.vue";

defineProps<{ order: ShopOrderSummary }>();
</script>
