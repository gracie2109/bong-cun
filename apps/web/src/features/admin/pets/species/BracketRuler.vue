<template>
  <!-- Each bracket drawn in proportion, gaps stay empty. -->
  <div class="relative h-8 overflow-hidden rounded-lg bg-muted">
    <div
      v-for="segment in segments"
      :key="segment.key"
      class="absolute top-0 flex h-full items-center justify-center overflow-hidden border-r border-white bg-primary/80 px-1 text-[11px] font-medium text-primary-foreground"
      :style="{ left: `${segment.left}%`, width: `${segment.width}%` }"
      :title="segment.label"
    >
      <span class="truncate">{{ segment.label }}</span>
    </div>
  </div>
</template>

<script lang="ts" setup>
defineProps<{
  /** Position and size of each bracket, as percentages of the ruler. */
  segments: { key: number; label: string; left: number; width: number }[];
}>();
</script>
