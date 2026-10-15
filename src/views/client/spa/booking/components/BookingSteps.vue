<template>
  <ol class="flex flex-wrap items-center gap-2 text-sm" :aria-label="$t('client.booking.title')">
    <li v-for="(item, index) in steps" :key="item" class="flex items-center gap-2" :aria-current="index === current ? 'step' : undefined">
      <span
        class="grid size-7 shrink-0 place-content-center rounded-full text-xs font-bold"
        :class="index < current ? 'bg-sage text-white' : index === current ? 'bg-foreground text-white' : 'bg-muted text-muted-foreground'"
      >
        <Check v-if="index < current" class="size-3.5" :stroke-width="3" />
        <template v-else>{{ index + 1 }}</template>
      </span>
      <span class="font-medium" :class="[index === current ? 'text-foreground' : 'hidden text-muted-foreground sm:inline']">
        {{ $t(`client.booking.steps.${item}`) }}
      </span>
      <span v-if="index < steps.length - 1" class="h-px w-4 bg-border sm:w-8" aria-hidden="true" />
    </li>
  </ol>
</template>

<script lang="ts" setup>
import { Check } from "lucide-vue-next";
import type { BookingStep } from "@/types/spaWeb";

defineProps<{ steps: BookingStep[]; current: number }>();
</script>
