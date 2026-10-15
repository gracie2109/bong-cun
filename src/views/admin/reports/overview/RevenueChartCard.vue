<template>
  <section class="rounded-xl border bg-white p-4">
    <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
      <h2 class="text-sm font-semibold">{{ $t("reports.chart.title") }}</h2>
      <div class="flex items-center gap-4">
        <span v-for="item in chartSeries" :key="item.key" class="flex items-center gap-1.5 text-xs text-muted-foreground">
          <i class="inline-block size-2.5 rounded-sm" :style="{ background: item.color }" />{{ item.label }}
        </span>
        <div class="flex gap-1 rounded-lg border p-0.5">
          <button
            v-for="item in BUCKETS"
            :key="item"
            type="button"
            class="rounded-md px-2 py-0.5 text-xs font-semibold transition-colors"
            :class="bucket === item ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
            @click="bucket = item"
          >
            {{ $t(`reports.buckets.${item}`) }}
          </button>
        </div>
      </div>
    </div>
    <p v-if="loading" class="py-24 text-center text-sm text-muted-foreground">{{ $t("reports.loading") }}</p>
    <StackedBarChart
      v-else
      :points="chartPoints"
      :series="chartSeries"
      :format-y="compactMoney"
      :format-value="money"
      :label="$t('reports.chart.title')"
    />
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import type { Bucket, SeriesPoint } from "@/repositories/reports";
import type { ChartPoint, ChartSeries } from "../shared/chartScale";
import { bucketLabel, formatDay, formatMonth } from "../shared/dateRange";
import { compactMoney, money } from "../shared/format";
import StackedBarChart from "../shared/StackedBarChart.vue";

const props = defineProps<{ points: SeriesPoint[]; loading?: boolean }>();
const bucket = defineModel<Bucket>("bucket", { required: true });

const BUCKETS: Bucket[] = ["day", "week", "month"];
const SHOP_COLOR = "#0F766E";
const SPA_COLOR = "#F59E0B";
const BOARDING_COLOR = "#6366F1";

const { t } = useI18n();

const chartSeries = computed<ChartSeries[]>(() => [
  { key: "shop", label: t("reports.segment.shop"), color: SHOP_COLOR },
  { key: "spa", label: t("reports.segment.spa"), color: SPA_COLOR },
  { key: "boarding", label: t("reports.segment.boarding"), color: BOARDING_COLOR },
]);

const tooltipTitle = (point: SeriesPoint): string =>
  bucket.value === "month"
    ? formatMonth(point.bucket)
    : bucket.value === "week"
      ? t("reports.chart.weekOf", { day: formatDay(point.bucket) })
      : formatDay(point.bucket);

const chartPoints = computed<ChartPoint[]>(() =>
  props.points.map((point) => ({
    key: point.bucket,
    label: bucketLabel(bucket.value, point.bucket),
    title: tooltipTitle(point),
    values: [point.shop, point.spa, point.boarding],
  }))
);
</script>
