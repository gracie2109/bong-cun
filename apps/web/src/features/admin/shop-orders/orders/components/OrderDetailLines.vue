<template>
  <section class="space-y-2">
    <h3 class="text-sm font-semibold">{{ $t("shop.checkout.items", { n: order.lines.length }) }}</h3>
    <p v-if="short.length" class="rounded-lg bg-red-50 p-2 text-xs text-red-700">{{ $t("shop.admin.short") }}</p>
    <ul class="divide-y rounded-lg border">
      <li v-for="line in order.lines" :key="`${line.productId}-${line.unitId}`" class="flex gap-3 p-3 text-sm">
        <div class="min-w-0 flex-1">
          <p class="font-medium">{{ line.name }}</p>
          <p class="text-xs text-muted-foreground">{{ money(line.unitPrice) }} × {{ line.qty }}<template v-if="line.unit"> {{ line.unit }}</template></p>
          <p v-if="check && line.trackStock" class="text-xs" :class="isShort(line) ? 'font-semibold text-red-600' : 'text-muted-foreground'">
            {{ $t("shop.admin.available", { n: line.available }) }}
          </p>
        </div>
        <p class="shrink-0 font-semibold">{{ money(line.amount) }}</p>
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { AdminOrder, AdminOrderLine } from "@bongcun/core/shop";
import { shortLines, showStockCheck } from "@bongcun/core/shop";
import { money } from "@/features/admin/pos/format";

const props = defineProps<{ order: AdminOrder }>();

const check = computed(() => showStockCheck(props.order.status));
const short = computed(() => (check.value ? shortLines(props.order.lines) : []));
const isShort = (line: AdminOrderLine) => short.value.includes(line);
</script>
