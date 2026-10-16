<template>
  <section class="space-y-4 rounded-3xl border bg-white p-5 sm:p-6">
    <h2 class="text-lg font-bold tracking-tight">{{ $t("shop.checkout.items", { n: lines.length }) }}</h2>
    <ul class="divide-y">
      <li v-for="line in lines" :key="`${line.productId}-${line.unitId}`" class="flex gap-3 py-3 first:pt-0 last:pb-0">
        <div class="size-16 shrink-0 overflow-hidden rounded-xl bg-white ring-1 ring-border/70">
          <img v-if="line.imageUrl" :src="line.imageUrl" alt="" class="size-full object-contain p-1" loading="lazy" />
          <div v-else class="grid size-full place-content-center bg-brand-soft text-brand"><PawMark class="size-6" /></div>
        </div>
        <div class="min-w-0 flex-1">
          <p class="line-clamp-2 text-sm font-semibold">{{ line.name }}</p>
          <p class="text-xs text-muted-foreground">
            {{ formatPrice(line.unitPrice) }} × {{ line.qty }}<template v-if="line.unit"> {{ line.unit }}</template>
          </p>
        </div>
        <p class="shrink-0 text-sm font-bold tabular-nums">{{ formatPrice(line.amount) }}</p>
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import PawMark from "@/components/shop/PawMark.vue";
import { formatPrice } from "@/lib/utils";
import type { ShopOrderLine } from "@bongcun/core/shop";

defineProps<{ lines: ShopOrderLine[] }>();
</script>
