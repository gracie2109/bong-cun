<template>
  <div class="flex flex-wrap gap-2">
    <button
      v-for="item in options"
      :key="item.id"
      type="button"
      class="flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm transition-colors"
      :class="selected.includes(item.id) ? 'border-primary bg-primary/10 text-primary' : 'hover:bg-muted'"
      :aria-pressed="selected.includes(item.id)"
      @click="toggle(item.id)"
    >
      <Icon v-if="item.icon" :icon="item.icon" class="size-4" />
      {{ item.name }}
    </button>
  </div>
</template>

<script lang="ts" setup>
import { Icon } from "@iconify/vue";

/** Options shown as toggleable chips; a chip with an `icon` shows it before the name. */
defineProps<{ options: { id: string; name: string; icon?: string | null }[] }>();

/** Ids of the chosen options. */
const selected = defineModel<string[]>({ required: true });

const toggle = (id: string) => {
  selected.value = selected.value.includes(id) ? selected.value.filter((item) => item !== id) : [...selected.value, id];
};
</script>
