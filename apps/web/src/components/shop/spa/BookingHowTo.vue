<template>
  <ol class="grid gap-6 sm:grid-cols-3 sm:gap-4">
    <li v-for="(step, index) in STEPS" :key="step.key" class="relative">
      <span
        v-if="index < STEPS.length - 1"
        class="absolute left-[52px] right-0 top-6 hidden h-px border-t border-dashed border-sage/40 sm:block"
        aria-hidden="true"
      />
      <span class="relative grid size-12 place-content-center rounded-2xl bg-white text-sage shadow-card">
        <component :is="step.icon" class="size-5" />
        <span class="absolute -right-1.5 -top-1.5 grid size-5 place-content-center rounded-full bg-sage text-[11px] font-bold text-white">
          {{ index + 1 }}
        </span>
      </span>
      <p class="mt-4 font-semibold">{{ $t(`client.spa.howTo.${step.key}`) }}</p>
      <p class="mt-1 text-sm text-muted-foreground">{{ $t(`client.spa.howTo.${step.key}Text`) }}</p>
    </li>
  </ol>
</template>

<script lang="ts" setup>
import { CalendarCheck, PawPrint, Store } from "lucide-vue-next";

/** How online spa booking works, in the order the booking wizard asks. */
const STEPS = [
  { key: "pick", icon: PawPrint },
  { key: "slot", icon: CalendarCheck },
  { key: "visit", icon: Store },
] as const;
</script>
