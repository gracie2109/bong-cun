<template>
  <svg :viewBox="`0 0 ${WIDTH} ${HEIGHT}`" class="h-24 w-full text-primary" role="img" :aria-label="$t('petCare.pets.detail.weightHistory')">
    <polyline :points="points" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" stroke-linecap="round" />
    <circle v-for="point in dots" :key="point.id" :cx="point.x" :cy="point.y" r="3" fill="currentColor" />
  </svg>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { PetWeightLog } from "@/repositories/pets";

const WIDTH = 300;
const HEIGHT = 96;
const PADDING = 8;

const props = defineProps<{ weights: PetWeightLog[] }>();

// Oldest first so the line runs left to right in time.
const dots = computed(() => {
  const ordered = [...props.weights].sort((a, b) => a.measuredAt.localeCompare(b.measuredAt));
  const values = ordered.map((log) => log.weightKg);
  const min = Math.min(...values);
  const span = Math.max(Math.max(...values) - min, 1e-6);
  const step = ordered.length > 1 ? (WIDTH - PADDING * 2) / (ordered.length - 1) : 0;

  return ordered.map((log, index) => ({
    id: log.id,
    x: PADDING + index * step,
    y: HEIGHT - PADDING - ((log.weightKg - min) / span) * (HEIGHT - PADDING * 2),
  }));
});

const points = computed(() => dots.value.map((dot) => `${dot.x},${dot.y}`).join(" "));
</script>
