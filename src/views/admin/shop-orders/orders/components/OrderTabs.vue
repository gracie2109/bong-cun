<template>
  <div class="flex flex-wrap gap-1">
    <button
      v-for="item in ORDER_TABS"
      :key="item"
      type="button"
      class="flex items-center gap-2 rounded-lg px-3 py-1.5 text-sm font-semibold transition-colors"
      :class="item === tab ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
      @click="tab = item"
    >
      {{ $t(`shop.admin.tabs.${item}`) }}
      <span
        v-if="count(item) !== null"
        class="rounded-full px-1.5 text-[11px]"
        :class="item === tab ? 'bg-white/25' : 'bg-muted'"
      >
        {{ count(item) }}
      </span>
    </button>
  </div>
</template>

<script lang="ts" setup>
import type { ShopOrderStatus } from "@/types/shopOrder";
import { ORDER_TABS, type OrderTab } from "@/types/shopOrderAdmin";

const props = defineProps<{ counts: Partial<Record<ShopOrderStatus, number>> }>();
const tab = defineModel<OrderTab>("tab", { required: true });

/** Orders in a tab; "all" shows no number. */
const count = (item: OrderTab): number | null => {
  if (item === "all") return null;
  if (item === "closed") return (props.counts.cancelled ?? 0) + (props.counts.returned ?? 0);
  return props.counts[item] ?? 0;
};
</script>
