<template>
  <section class="space-y-5 rounded-3xl border bg-white p-5 sm:p-6">
    <p v-if="order.status === 'cancelled' || order.status === 'returned'" class="text-sm">
      <span class="font-semibold">{{ $t(`shop.order.status.${order.status}`) }}</span>
      <span v-if="order.cancelReason" class="text-muted-foreground"> · {{ order.cancelReason }}</span>
    </p>
    <ol v-else class="grid gap-4 sm:grid-flow-col sm:auto-cols-fr">
      <li v-for="step in steps" :key="step.status" class="flex gap-3 sm:flex-col sm:gap-1.5">
        <span
          class="grid size-7 shrink-0 place-content-center rounded-full border text-xs font-bold"
          :class="{
            'border-sage bg-sage text-white': step.state === 'done',
            'border-foreground bg-foreground text-white ring-4 ring-foreground/10': step.state === 'current',
            'text-muted-foreground': step.state === 'todo',
          }"
        >
          <Check v-if="step.state === 'done'" class="size-4" />
        </span>
        <div>
          <p class="text-sm font-semibold" :class="{ 'text-muted-foreground': step.state === 'todo' }">
            {{ $t(`shop.order.status.${step.status}`) }}
          </p>
          <p v-if="step.at" class="text-xs text-muted-foreground">{{ formatDateTime(step.at) }}</p>
        </div>
      </li>
    </ol>

    <div v-if="order.trackingCode" class="rounded-2xl bg-secondary/70 p-3.5 text-sm">
      {{ $t("shop.order.tracking", { carrier: order.carrier ?? "GHN" }) }}
      <span class="font-mono font-semibold">{{ order.trackingCode }}</span>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { Check } from "lucide-vue-next";
import type { ShopOrderDetail } from "@bongcun/core/shop";
import { formatDateTime, type OrderStep } from "@/utils/shop/order";

defineProps<{ order: ShopOrderDetail; steps: OrderStep[] }>();
</script>
