<template>
  <article class="group relative flex h-full flex-col rounded-3xl border bg-white p-5 transition-[box-shadow,transform] duration-300 ease-out-quart hover:-translate-y-1 hover:shadow-lift md:p-6">
    <div class="flex items-start justify-between gap-3">
      <span class="grid size-11 shrink-0 place-content-center rounded-2xl bg-sage-soft text-sage"><Sparkles class="size-5" /></span>
      <span v-if="combo.mark !== '4'" class="rounded-full bg-brand-soft px-2.5 py-1 text-[11px] font-bold uppercase tracking-wide text-accent-foreground">
        {{ $t(`client.spa.marks.${combo.mark}`) }}
      </span>
    </div>
    <h3 class="mt-4 text-lg font-bold leading-snug">{{ combo.name }}</h3>
    <ul v-if="combo.serviceNames.length" class="mt-3 space-y-1.5 text-sm text-muted-foreground">
      <li v-for="name in combo.serviceNames" :key="name" class="flex items-start gap-2">
        <Check class="mt-0.5 size-4 shrink-0 text-sage" :stroke-width="2.5" />{{ name }}
      </li>
    </ul>
    <p v-if="combo.description" class="mt-3 text-sm text-muted-foreground">{{ combo.description }}</p>
    <div class="mt-auto flex flex-wrap items-end justify-between gap-3 pt-5">
      <PriceDisplay :amount="combo.price" :compare-at="combo.originPrice" />
      <span v-if="duration(combo.durationMinutes)" class="inline-flex items-center gap-1 text-xs text-muted-foreground">
        <Clock class="size-3.5" />{{ duration(combo.durationMinutes) }}
      </span>
    </div>
  </article>
</template>

<script lang="ts" setup>
import { Check, Clock, Sparkles } from "lucide-vue-next";
import { useDurationLabel } from "@/composables/spa/useDurationLabel";
import type { SpaCombo } from "@/types/spaCatalog";
import PriceDisplay from "../PriceDisplay.vue";

defineProps<{ combo: SpaCombo }>();
const duration = useDurationLabel();
</script>
