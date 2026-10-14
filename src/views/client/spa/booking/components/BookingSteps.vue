<template>
  <ol class="flex items-center gap-2 text-sm" :aria-label="$t('client.booking.title')">
    <li v-for="(item, index) in steps" :key="item" class="flex items-center gap-2" :aria-current="index === current ? 'step' : undefined">
      <span
        class="flex size-6 shrink-0 items-center justify-center rounded-full text-xs font-semibold"
        :class="index <= current ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground'"
      >
        {{ index + 1 }}
      </span>
      <span class="hidden sm:inline" :class="index === current ? 'font-semibold' : 'text-muted-foreground'">
        {{ $t(`client.booking.steps.${item}`) }}
      </span>
      <span v-if="index < steps.length - 1" class="h-px w-4 bg-border sm:w-8" />
    </li>
  </ol>
</template>

<script lang="ts" setup>
import type { BookingStep } from "@/types/spaWeb";

defineProps<{ steps: BookingStep[]; current: number }>();
</script>
