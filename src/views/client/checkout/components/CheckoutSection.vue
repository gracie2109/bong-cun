<template>
  <section class="rounded-3xl border bg-white p-5 sm:p-6" :aria-labelledby="headingId">
    <div class="flex items-center justify-between gap-3">
      <h2 :id="headingId" class="flex items-center gap-3 text-lg font-bold tracking-tight">
        <span class="grid size-7 shrink-0 place-content-center rounded-full bg-foreground text-xs font-bold text-white">{{ step }}</span>
        {{ title }}
      </h2>
      <slot name="action" />
    </div>
    <div class="mt-4"><slot /></div>
  </section>
</template>

<script lang="ts" setup>
import { useId } from "vue";

/** One numbered block of the checkout form (method, address, items). */
defineProps<{ step: number; title: string }>();
const headingId = useId();
</script>
