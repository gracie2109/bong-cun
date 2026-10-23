<template>
  <WidgetCard
    :title="$t('dashboard.trend.title')"
    :icon="TrendingUp"
    :state="state"
    :to="{ name: 'reportsOverview', query: { preset: 'last7' } }"
    :link-label="$t('dashboard.sales.open')"
    :empty-text="$t('dashboard.trend.empty')"
    @retry="refetch()"
  >
    <div class="mb-2 flex flex-wrap items-center justify-between gap-2">
      <div class="flex flex-wrap gap-3">
        <span v-for="item in series" :key="item.key" class="flex items-center gap-1.5 text-xs text-muted-foreground">
          <i class="inline-block size-2.5 rounded-sm" :style="{ background: item.color }" />{{ item.label }}
        </span>
      </div>
      <div class="flex gap-1 rounded-lg border p-0.5">
        <button
          v-for="item in TREND_DAYS"
          :key="item"
          type="button"
          class="rounded-md px-2 py-0.5 text-xs font-semibold transition-colors"
          :class="days === item ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
          @click="days = item"
        >
          {{ $t("dashboard.trend.days", { n: item }) }}
        </button>
      </div>
    </div>
    <StackedBarChart
      :points="chartPoints"
      :series="series"
      :format-y="compactMoney"
      :format-value="money"
      :label="$t('dashboard.trend.title')"
    />
  </WidgetCard>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { TrendingUp } from "lucide-vue-next";
import { bucketLabel, compactMoney, formatDay, money, StackedBarChart, type ChartSeries } from "@/features/admin/reports";
import WidgetCard from "../../kit/WidgetCard.vue";
import { TREND_DAYS, toChartPoints } from "./trend";
import { useRevenueTrend } from "./useRevenueTrend";

const { t } = useI18n();
const { state, days, points, refetch } = useRevenueTrend();

const series = computed<ChartSeries[]>(() => [
  { key: "shop", label: t("reports.segment.shop"), color: "#0F766E" },
  { key: "spa", label: t("reports.segment.spa"), color: "#F59E0B" },
  { key: "boarding", label: t("reports.segment.boarding"), color: "#6366F1" },
  { key: "medical", label: t("reports.segment.medical"), color: "#E11D48" },
]);
const chartPoints = computed(() =>
  toChartPoints(points.value, (iso) => bucketLabel("day", iso), formatDay)
);
</script>
