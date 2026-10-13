<template>
  <section class="space-y-3 rounded-xl border bg-white p-5">
    <h2 class="text-lg font-semibold">{{ $t("shop.checkout.items", { n: lines.length }) }}</h2>
    <ul class="divide-y">
      <li v-for="line in lines" :key="`${line.productId}-${line.unitId}`" class="flex gap-3 py-3 first:pt-0 last:pb-0">
        <div class="size-14 shrink-0 overflow-hidden rounded-lg bg-muted/40">
          <img v-if="line.imageUrl" :src="line.imageUrl" alt="" class="size-full object-cover" loading="lazy" />
          <div v-else class="grid size-full place-content-center"><ImageIcon class="size-5 text-muted-foreground" /></div>
        </div>
        <div class="min-w-0 flex-1">
          <p class="line-clamp-2 text-sm font-medium">{{ line.name }}</p>
          <p class="text-xs text-muted-foreground">
            {{ formatPrice(line.unitPrice) }} × {{ line.qty }}<template v-if="line.unit"> {{ line.unit }}</template>
          </p>
        </div>
        <p class="shrink-0 text-sm font-semibold">{{ formatPrice(line.amount) }}</p>
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { Image as ImageIcon } from "lucide-vue-next";
import { formatPrice } from "@/lib/utils";
import type { ShopOrderLine } from "@/types/shopOrder";

defineProps<{ lines: ShopOrderLine[] }>();
</script>
