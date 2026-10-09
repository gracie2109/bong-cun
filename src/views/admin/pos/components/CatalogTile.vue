<template>
  <button
    type="button"
    class="flex min-h-20 flex-col justify-between rounded-lg border p-3 text-left transition-colors hover:border-primary hover:bg-primary/5 disabled:cursor-not-allowed disabled:opacity-50 disabled:hover:border-border disabled:hover:bg-transparent"
    :disabled="stock === 0"
    @click="emit('choose')"
  >
    <span class="flex items-start justify-between gap-2">
      <span class="line-clamp-2 text-sm font-semibold">{{ item.name }}</span>
      <span
        v-if="stock !== undefined"
        class="shrink-0 rounded-full px-1.5 py-0.5 text-[10px] font-semibold"
        :class="stock === 0 ? 'bg-red-50 text-red-600' : 'bg-muted text-muted-foreground'"
      >
        {{ stock === 0 ? $t("pos.catalog.outOfStock") : $t("pos.catalog.inStock", { n: qty(stock) }) }}
      </span>
    </span>
    <span class="mt-1 flex items-end justify-between gap-2">
      <span class="truncate text-[11px] text-muted-foreground">{{ item.hint }}</span>
      <span class="whitespace-nowrap text-sm font-bold text-primary">
        <template v-if="item.price === null">{{ $t("pos.catalog.byWeight") }}</template>
        <template v-else-if="item.maxPrice && item.maxPrice > item.price">
          {{ $t("pos.variant.from", { price: money(item.price) }) }}
        </template>
        <template v-else>{{ money(item.price) }}</template>
      </span>
    </span>
  </button>
</template>

<script lang="ts" setup>
import { qty } from "@/views/admin/inventory/format";
import { money } from "../format";
import type { CatalogItem } from "../catalog";

defineProps<{
  item: CatalogItem;
  /** Units in stock; undefined when stock is not tracked for this tile. */
  stock: number | undefined;
}>();

const emit = defineEmits<{ choose: [] }>();
</script>
