<template>
  <div class="grid gap-3 sm:grid-cols-2">
    <article v-for="combo in combos" :key="combo.id" class="flex flex-col gap-2 rounded-xl border bg-white p-4">
      <div class="flex items-start justify-between gap-2">
        <h3 class="font-semibold">{{ combo.name }}</h3>
        <span
          v-if="combo.mark !== '4'"
          class="shrink-0 rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-semibold text-primary"
        >
          {{ $t(`client.spa.marks.${combo.mark}`) }}
        </span>
      </div>
      <p v-if="combo.serviceNames.length" class="text-sm text-muted-foreground">{{ combo.serviceNames.join(" + ") }}</p>
      <p v-if="combo.description" class="text-sm text-muted-foreground">{{ combo.description }}</p>
      <div class="mt-auto flex flex-wrap items-baseline gap-2 pt-1">
        <span v-if="combo.price !== null" class="text-lg font-bold text-primary">{{ formatPrice(combo.price) }}</span>
        <span v-if="saving(combo) > 0" class="text-sm text-muted-foreground line-through">{{ formatPrice(combo.originPrice ?? 0) }}</span>
        <span v-if="saving(combo) > 0" class="rounded bg-red-50 px-1.5 py-0.5 text-[11px] font-semibold text-red-600">
          -{{ saving(combo) }}%
        </span>
        <span v-if="duration(combo.durationMinutes)" class="ml-auto text-xs text-muted-foreground">
          {{ duration(combo.durationMinutes) }}
        </span>
      </div>
    </article>
  </div>
</template>

<script lang="ts" setup>
import { useDurationLabel } from "@/composables/spa/useDurationLabel";
import { formatPrice } from "@/lib/utils";
import type { SpaCombo } from "@/types/spaCatalog";
import { comboSavingPercent } from "@/utils/spa/catalog";

defineProps<{ combos: SpaCombo[] }>();

const duration = useDurationLabel();
const saving = comboSavingPercent;
</script>
