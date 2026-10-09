<template>
  <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
    <div v-for="card in cards" :key="card.label" class="rounded-xl border bg-white p-4">
      <div class="flex items-start justify-between gap-2">
        <p class="text-[11px] font-bold uppercase tracking-wider text-muted-foreground">{{ card.label }}</p>
        <span class="flex size-8 items-center justify-center rounded-lg" :class="card.tone">
          <Icon :icon="card.icon" class="size-4" />
        </span>
      </div>
      <p class="mt-2 flex items-baseline gap-2">
        <span class="text-3xl font-bold" :class="card.valueClass">{{ card.value }}</span>
        <span class="text-sm text-muted-foreground">{{ card.unit }}</span>
      </p>
      <p class="mt-1 text-xs text-muted-foreground">{{ card.note }}</p>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Icon } from "@iconify/vue";
import type { StatCard } from "./usePermissionCatalog";

defineProps<{ cards: StatCard[] }>();
</script>
