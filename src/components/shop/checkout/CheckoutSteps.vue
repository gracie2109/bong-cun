<template>
  <ol class="flex items-center gap-2 text-sm" :aria-label="$t('shop.steps.label')">
    <li v-for="(step, index) in STEPS" :key="step" class="flex items-center gap-2">
      <span
        class="grid size-7 place-content-center rounded-full text-xs font-bold"
        :class="index < current ? 'bg-sage text-white' : index === current ? 'bg-foreground text-white' : 'bg-muted text-muted-foreground'"
      >
        <Check v-if="index < current" class="size-3.5" :stroke-width="3" />
        <template v-else>{{ index + 1 }}</template>
      </span>
      <span class="hidden font-medium sm:inline" :class="index === current ? 'text-foreground' : 'text-muted-foreground'" :aria-current="index === current ? 'step' : undefined">
        {{ $t(`shop.steps.${step}`) }}
      </span>
      <span v-if="index < STEPS.length - 1" class="mx-1 h-px w-6 bg-border sm:w-10" aria-hidden="true" />
    </li>
  </ol>
</template>

<script lang="ts" setup>
import { Check } from "lucide-vue-next";

/** Where the shopper is in cart -> checkout -> done. */
defineProps<{ current: 0 | 1 | 2 }>();
const STEPS = ["cart", "checkout", "done"] as const;
</script>
