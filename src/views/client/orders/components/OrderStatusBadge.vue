<template>
  <span class="rounded-full px-2.5 py-0.5 text-xs font-semibold" :class="STATUS_TONE[status]">
    {{ $t(`shop.order.status.${status}`) }}
  </span>
</template>

<script lang="ts" setup>
import type { ShopOrderStatus } from "@/types/shopOrder";
import { STATUS_TONE } from "@/utils/shop/order";

defineProps<{ status: ShopOrderStatus }>();
</script>
