<template>
  <button
    type="button"
    class="flex w-full items-center gap-3 border-b px-4 py-3 text-left transition-colors last:border-b-0 hover:bg-muted/40"
    :class="selected ? 'bg-primary/5' : ''"
  >
    <span class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
      <Icon v-if="species.icon" :icon="species.icon" class="size-5" />
      <PawPrint v-else class="size-5" />
    </span>
    <span class="min-w-0 flex-1">
      <span class="flex items-center gap-2 font-semibold">
        <span class="truncate">{{ species.name }}</span>
        <span
          v-if="!species.isActive"
          class="rounded-full bg-muted px-2 py-0.5 text-[10px] font-semibold text-muted-foreground"
        >
          {{ $t("petCare.common.archived") }}
        </span>
      </span>
      <span class="block text-xs text-muted-foreground">
        {{ $t("petCare.species.counts", { pets: species.petCount, services: species.serviceCount }) }}
      </span>
    </span>
  </button>
</template>

<script lang="ts" setup>
import { Icon } from "@iconify/vue";
import { PawPrint } from "lucide-vue-next";
import type { SpeciesSummary } from "@/repositories/species";

defineProps<{ species: SpeciesSummary; selected: boolean }>();
</script>
