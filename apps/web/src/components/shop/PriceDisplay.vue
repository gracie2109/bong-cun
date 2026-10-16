<template>
  <p v-if="priced" class="flex flex-wrap items-baseline gap-x-2 gap-y-0.5 tabular-nums">
    <span v-if="from" class="text-xs font-medium text-muted-foreground">{{ $t("client.catalog.from") }}</span>
    <span class="font-bold tracking-tight" :class="[SIZE[size], onSale ? 'text-destructive' : 'text-foreground']">
      {{ formatPrice(amount ?? 0) }}
    </span>
    <template v-if="onSale">
      <s class="text-muted-foreground" :class="size === 'lg' ? 'text-base' : 'text-xs'">{{ formatPrice(compareAt ?? 0) }}</s>
      <span class="rounded-full bg-destructive/10 px-1.5 py-0.5 text-[11px] font-bold text-destructive">-{{ percent }}%</span>
    </template>
  </p>
  <p v-else class="text-sm text-muted-foreground">{{ $t("client.catalog.contactPrice") }}</p>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { formatPrice } from "@/lib/utils";
import { salePercent } from "@bongcun/core/shop";

/** A price in the shop's style; with `compareAt` above it, shows the old price struck out and the saving. */
const props = withDefaults(
  defineProps<{ amount: number | null; compareAt?: number | null; from?: boolean; size?: "sm" | "md" | "lg" }>(),
  { compareAt: null, from: false, size: "md" }
);

const SIZE = { sm: "text-sm", md: "text-base sm:text-[17px]", lg: "text-3xl" } as const;

// No price yet: null, or 0 left by a product created without one.
const priced = computed(() => props.amount !== null && props.amount > 0);
const percent = computed(() => salePercent(props.amount, props.compareAt));
const onSale = computed(() => percent.value > 0);
</script>
