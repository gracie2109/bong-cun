<template>
  <tr class="cursor-pointer border-t hover:bg-muted/40" @click="emit('open')">
    <td class="px-4 py-3 font-semibold">{{ order.code }}</td>
    <td class="whitespace-nowrap px-4 py-3">{{ dateTime(order.placedAt) }}</td>
    <td class="px-4 py-3">
      {{ order.receiverName }}
      <span class="block text-xs text-muted-foreground">{{ order.receiverPhone }}</span>
    </td>
    <td class="whitespace-nowrap px-4 py-3">{{ $t(`shop.checkout.methods.${order.deliveryMethod}`) }}</td>
    <td class="px-4 py-3 text-right">{{ order.lineCount }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{{ money(order.total) }}</td>
    <td class="px-4 py-3"><OrderStatusBadge :status="order.status" /></td>
    <td class="whitespace-nowrap px-4 py-3 font-mono text-xs">{{ order.trackingCode }}</td>
  </tr>
</template>

<script lang="ts" setup>
import type { AdminOrderRow } from "@/types/shopOrderAdmin";
import OrderStatusBadge from "@/components/common/OrderStatusBadge.vue";
import { dateTime, money } from "@/views/admin/pos/format";

defineProps<{ order: AdminOrderRow }>();
const emit = defineEmits<{ open: [] }>();
</script>
