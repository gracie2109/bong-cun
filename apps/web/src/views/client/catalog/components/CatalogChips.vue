<template>
  <TransitionGroup tag="div" name="chip" class="flex flex-wrap items-center gap-2" :class="{ hidden: chips.length === 0 }">
    <button
      v-for="chip in chips"
      :key="chip.key"
      type="button"
      class="inline-flex h-9 items-center gap-1.5 rounded-full bg-accent pl-3.5 pr-2.5 text-sm font-medium text-accent-foreground transition-colors hover:bg-primary/15"
      :aria-label="$t('client.catalog.removeFilter', { label: chip.label })"
      @click="chip.remove()"
    >
      {{ chip.label }}<X class="size-3.5" />
    </button>
    <button
      v-if="chips.length > 1"
      key="clear-all"
      type="button"
      class="h-9 px-2 text-sm font-semibold text-foreground underline-offset-4 hover:underline"
      @click="emit('clear')"
    >
      {{ $t("client.catalog.clear") }}
    </button>
  </TransitionGroup>
</template>

<script lang="ts" setup>
import { X } from "lucide-vue-next";
import type { FilterChip } from "@/types/catalog";

defineProps<{ chips: FilterChip[] }>();
const emit = defineEmits<{ clear: [] }>();
</script>

<style scoped>
.chip-enter-active,
.chip-leave-active {
  transition: opacity 200ms var(--ease-out), transform 200ms var(--ease-out);
}
.chip-enter-from,
.chip-leave-to {
  opacity: 0;
  transform: scale(0.9);
}
.chip-leave-active {
  position: absolute;
}
.chip-move {
  transition: transform 240ms var(--ease-out);
}
</style>
