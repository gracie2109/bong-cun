<template>
  <MetricWidgetBody v-if="resolved" :key="resolved.def.key" :resolved="resolved" />
  <MetricUnavailable v-else />
</template>

<script lang="ts" setup>
// The component behind the kpi, barChart and list widget types: the metric decides what is drawn
// (a figure, bars or a list), so one component serves all three.
import { computed } from "vue";
import MetricUnavailable from "./MetricUnavailable.vue";
import MetricWidgetBody from "./MetricWidgetBody.vue";
import { resolveMetricConfig } from "./metricConfig";

const props = defineProps<{ config?: Record<string, unknown> }>();
const resolved = computed(() => resolveMetricConfig(props.config));
</script>
