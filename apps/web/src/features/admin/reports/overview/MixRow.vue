<template>
  <div class="py-1" :class="sub ? 'pl-4 text-xs text-muted-foreground' : 'text-sm'">
    <div class="flex items-center justify-between gap-3">
      <span>{{ label }}</span>
      <span class="whitespace-nowrap">
        <span class="font-semibold" :class="sub ? '' : 'text-foreground'">{{ money(value) }}</span>
        <span class="ml-2 inline-block w-12 text-right text-xs text-muted-foreground">{{ share }}</span>
      </span>
    </div>
    <div v-if="color" class="mt-1 h-1.5 overflow-hidden rounded-full bg-muted">
      <div class="h-full rounded-full" :style="{ width: share, background: color }" />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { money, percent } from "../shared/format";

const props = defineProps<{ label: string; value: number; total: number; color?: string; sub?: boolean }>();

const share = computed(() => (props.total > 0 ? percent(Math.max(0, (props.value / props.total) * 100)) : "0%"));
</script>
