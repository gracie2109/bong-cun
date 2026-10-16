<template>
  <div ref="host" class="relative overflow-x-auto" :style="{ height: `${HEIGHT}px` }">
    <svg :width="chartWidth" :height="HEIGHT" role="img" :aria-label="label" @mouseleave="hovered = null">
      <g :transform="`translate(${AXIS_WIDTH}, ${PAD_TOP})`">
        <g v-for="tick in ticks" :key="tick">
          <line x1="0" :x2="plotWidth" :y1="yOf(tick)" :y2="yOf(tick)" class="stroke-border" stroke-dasharray="3 3" />
          <text x="-8" :y="yOf(tick) + 4" text-anchor="end" class="fill-muted-foreground text-[10px]">{{ formatY(tick) }}</text>
        </g>
        <g v-for="(bar, index) in bars" :key="points[index].key" @mouseenter="hovered = index">
          <rect :x="index * slot" y="0" :width="slot" :height="plotHeight" fill="transparent" />
          <rect
            v-for="(segment, s) in bar.segments"
            :key="series[s].key"
            :x="bar.x"
            :y="segment.y"
            :width="bar.width"
            :height="segment.height"
            :fill="series[s].color"
            :opacity="hovered === null || hovered === index ? 1 : 0.55"
          />
        </g>
        <text
          v-for="index in labelIndexes"
          :key="points[index].key"
          :x="index * slot + slot / 2"
          :y="plotHeight + 16"
          text-anchor="middle"
          class="fill-muted-foreground text-[10px]"
        >
          {{ points[index].label }}
        </text>
      </g>
    </svg>
    <div
      v-if="hoveredPoint"
      class="pointer-events-none absolute top-1 z-10 min-w-40 rounded-lg border bg-white p-2 text-xs shadow-md"
      :style="{ left: `${tooltipLeft}px` }"
    >
      <p class="mb-1 font-semibold">{{ hoveredPoint.title }}</p>
      <p v-for="(item, s) in series" :key="item.key" class="flex items-center justify-between gap-4">
        <span class="flex items-center gap-1.5"><i class="inline-block size-2 rounded-sm" :style="{ background: item.color }" />{{ item.label }}</span>
        <span class="font-semibold">{{ formatValue(hoveredPoint.values[s]) }}</span>
      </p>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { useElementSize } from "@vueuse/core";
import { axisTicks, barGeometry, niceMax, type ChartPoint, type ChartSeries } from "./chartScale";

const props = defineProps<{
  points: ChartPoint[];
  series: ChartSeries[];
  formatY: (value: number) => string;
  formatValue: (value: number) => string;
  label: string;
}>();

const HEIGHT = 260;
const AXIS_WIDTH = 48;
const PAD_TOP = 8;
const PAD_BOTTOM = 28;
const MIN_SLOT = 26;
const LABEL_WIDTH = 46;
const BAR_GAP = 6;
const TOOLTIP_WIDTH = 170;

const host = ref<HTMLElement>();
const { width: hostWidth } = useElementSize(host);
const hovered = ref<number | null>(null);

const plotHeight = HEIGHT - PAD_TOP - PAD_BOTTOM;
// Bars share the width; below MIN_SLOT each the chart scrolls sideways instead.
const slot = computed(() =>
  Math.max(MIN_SLOT, (hostWidth.value - AXIS_WIDTH - 8) / Math.max(props.points.length, 1))
);
const plotWidth = computed(() => slot.value * props.points.length);
const chartWidth = computed(() => plotWidth.value + AXIS_WIDTH + 8);

const max = computed(() => niceMax(Math.max(...props.points.map((point) => point.values.reduce((sum, v) => sum + Math.max(v, 0), 0)), 0)));
const ticks = computed(() => axisTicks(max.value));
const yOf = (value: number) => plotHeight - (value / max.value) * plotHeight;

const bars = computed(() =>
  props.points.map((point, index) =>
    barGeometry({ values: point.values, index, max: max.value, plotHeight, slot: slot.value, gap: BAR_GAP })
  )
);

// Label every n-th bar so the labels do not overlap.
const labelIndexes = computed(() => {
  const every = Math.max(1, Math.ceil(LABEL_WIDTH / slot.value));
  return props.points.map((_, index) => index).filter((index) => index % every === 0);
});

const hoveredPoint = computed(() => (hovered.value === null ? null : props.points[hovered.value]));
const tooltipLeft = computed(() => {
  const x = AXIS_WIDTH + (hovered.value ?? 0) * slot.value + slot.value / 2;
  return Math.max(0, Math.min(x - TOOLTIP_WIDTH / 2, chartWidth.value - TOOLTIP_WIDTH));
});
</script>
