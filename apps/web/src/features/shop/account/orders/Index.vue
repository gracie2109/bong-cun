<template>
  <div class="mx-auto w-full max-w-3xl space-y-4 pb-10">
    <div class="flex flex-wrap gap-1.5">
      <button
        v-for="item in FILTERS"
        :key="item ?? 'all'"
        type="button"
        class="rounded-full border px-3 py-1 text-sm font-medium transition"
        :class="item === status ? 'border-primary bg-primary text-white' : 'hover:border-primary/50'"
        @click="status = item"
      >
        {{ $t(item ? `shop.order.status.${item}` : "shop.order.all") }}
      </button>
    </div>

    <p v-if="loading" class="py-12 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="failed" class="py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("shop.order.listFailed") }}</p>
      <Button variant="outline" @click="retry()">{{ $t("shop.cart.retry") }}</Button>
    </div>
    <div v-else-if="rows.length === 0" class="py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("shop.order.empty") }}</p>
      <Button as-child variant="outline"><router-link :to="{ name: 'products' }">{{ $t("shop.cart.continue") }}</router-link></Button>
    </div>
    <template v-else>
      <ul class="space-y-3" :class="fetching && 'opacity-60'">
        <OrderCard v-for="order in rows" :key="order.id" :order="order" />
      </ul>
      <div class="flex items-center justify-between text-sm text-muted-foreground">
        <span>{{ $t("common.table.range", { from: (page - 1) * 10 + 1, to: (page - 1) * 10 + rows.length, total }) }}</span>
        <TablePager v-model:page="page" :page-count="pageCount" :loading="fetching" />
      </div>
    </template>
  </div>
</template>

<script lang="ts" setup>
import TablePager from "@/components/common/TablePager.vue";
import { Button } from "@/components/ui/button";
import { useMyOrders } from "@/composables/shop/useMyOrders";
import type { ShopOrderStatus } from "@bongcun/core/shop";
import OrderCard from "./OrderCard.vue";

const FILTERS: (ShopOrderStatus | null)[] = [null, "pending", "confirmed", "packed", "shipping", "completed", "cancelled"];

const { status, page, rows, total, pageCount, loading, fetching, failed, retry } = useMyOrders();
</script>
