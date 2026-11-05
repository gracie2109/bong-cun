<template>
  <WidgetCard
    :title="title"
    :icon="icon"
    :state="state"
    :to="resolved.def.route ? { name: resolved.def.route } : undefined"
    @retry="refetch()"
  >
    <p v-if="rangeText" class="-mt-2 mb-2 text-xs text-muted-foreground">{{ rangeText }}</p>

    <template v-if="value?.kind === 'number'">
      <p class="text-3xl font-bold tracking-tight">{{ formatFigure(value.value, resolved.def.format, money) }}</p>
      <p v-if="change" class="mt-1 text-xs">
        <span class="font-semibold" :class="TONE_CLASS[tone]">{{ ARROW[change.direction] }} {{ percent(change.percent) }}</span>
        <span class="text-muted-foreground"> {{ $t("reports.vsPrevious") }}</span>
      </p>
    </template>

    <LineChart
      v-else-if="value?.kind === 'series' && isLine"
      :points="linePoints"
      :format-y="compactMoney"
      :format-value="money"
      :label="title"
    />

    <StackedBarChart
      v-else-if="value?.kind === 'series'"
      :points="chartPoints"
      :series="chartSeries"
      :format-y="compactMoney"
      :format-value="money"
      :label="title"
    />

    <ol v-else-if="value?.kind === 'list'" class="space-y-2">
      <li v-for="(row, index) in value.rows" :key="row.key" class="flex items-center gap-3 text-sm">
        <span class="w-5 text-right text-xs font-semibold text-muted-foreground">{{ index + 1 }}</span>
        <span class="min-w-0 flex-1 truncate font-medium">{{ row.label }}</span>
        <span class="font-semibold">{{ formatFigure(row.value, row.format, money) }}</span>
      </li>
    </ol>
  </WidgetCard>
</template>

<script lang="ts" setup>
import { computed, toRef } from "vue";
import { useI18n } from "vue-i18n";
import { compactMoney, formatDay, LineChart, money, percent, StackedBarChart, type ChartPoint, type ChartSeries, type LinePoint } from "@/features/admin/reports";
import WidgetCard from "../../kit/WidgetCard.vue";
import { rangeLabel } from "../../range/widgetRange";
import { GROUP_ICONS } from "./groupIcons";
import { changeOf, changeTone, formatFigure } from "./kpiFormat";
import type { ResolvedMetric } from "./metricConfig";
import { paramText } from "./paramText";
import { useMetricWidget } from "./useMetricWidget";

const props = defineProps<{ resolved: ResolvedMetric }>();
const { t, te } = useI18n();
const { state, value, title, refetch } = useMetricWidget(toRef(props, "resolved"));

const icon = computed(() => GROUP_ICONS[props.resolved.def.group]);
const change = computed(() =>
  props.resolved.compare && value.value?.kind === "number" ? changeOf(value.value.value, value.value.previous) : null
);
const tone = computed(() => (change.value ? changeTone(change.value.direction, props.resolved.def.riseIsBad) : "flat"));
const ARROW = { up: "▲", down: "▼", flat: "•" } as const;
const TONE_CLASS = { good: "text-emerald-600", bad: "text-red-600", flat: "text-muted-foreground" } as const;

const rangeText = computed(() => {
  const params = paramText(props.resolved.params, t, te);
  if (!props.resolved.def.usesRange) return params;
  const label = rangeLabel(props.resolved.range, props.resolved.def.defaultRange ?? "today");
  const days = label.kind === "preset" ? t(`dashboard.range.${label.preset}`) : `${formatDay(label.from)} - ${formatDay(label.to)}`;
  return [params, days].filter(Boolean).join(" · ");
});

const isLine = computed(() => props.resolved.view === "lineChart");
const linePoints = computed<LinePoint[]>(() =>
  value.value?.kind === "series" ? value.value.points.map((point) => ({ key: point.key, label: point.label, title: point.label, value: point.value })) : []
);
const chartSeries = computed<ChartSeries[]>(() => [{ key: "v", label: title.value, color: "#0F766E" }]);
const chartPoints = computed<ChartPoint[]>(() =>
  value.value?.kind === "series"
    ? value.value.points.map((point) => ({ key: point.key, label: point.label, title: point.label, values: [point.value] }))
    : []
);
</script>
