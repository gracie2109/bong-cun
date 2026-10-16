<template>
  <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
    <button
      v-for="chip in ALERTS"
      :key="chip.status"
      type="button"
      class="flex items-center justify-between gap-3 rounded-xl border bg-white p-4 text-left transition-colors hover:border-primary"
      :class="status === chip.status ? 'border-primary ring-1 ring-primary' : ''"
      :aria-pressed="status === chip.status"
      @click="status = status === chip.status ? 'all' : chip.status"
    >
      <span>
        <span class="block text-sm text-muted-foreground">
          {{ $t(`inventory.stock.alerts.${chip.status}`, { days: expiryDays }) }}
        </span>
        <span class="text-2xl font-bold" :class="(alerts?.[chip.status] ?? 0) > 0 ? chip.tone : ''">
          {{ alerts?.[chip.status] ?? "–" }}
        </span>
      </span>
      <component :is="chip.icon" class="size-6 text-muted-foreground" />
    </button>
  </div>
</template>

<script lang="ts" setup>
import { AlarmClock, PackageX, TrendingDown, TriangleAlert } from "lucide-vue-next";
import type { StockAlertCounts, StockStatus } from "@/repositories/inventory";

/** Alerts shown as cards; clicking one filters the list to it. */
const ALERTS = [
  { status: "low", icon: TrendingDown, tone: "text-amber-700" },
  { status: "out", icon: PackageX, tone: "text-red-600" },
  { status: "expiring", icon: AlarmClock, tone: "text-amber-700" },
  { status: "expired", icon: TriangleAlert, tone: "text-red-600" },
] as const;

defineProps<{
  /** Number of products per alert; undefined while loading. */
  alerts: StockAlertCounts | undefined;
  expiryDays: number;
}>();

const status = defineModel<StockStatus>("status", { required: true });
</script>
