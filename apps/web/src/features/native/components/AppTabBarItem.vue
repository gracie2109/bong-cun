<template>
  <button
    type="button"
    class="relative flex flex-1 flex-col items-center justify-center gap-0.5 py-1.5 text-[11px] font-medium transition-colors"
    :class="active ? 'text-primary' : 'text-muted-foreground'"
    :aria-current="active ? 'page' : undefined"
    @click="$emit('open')"
  >
    <span class="relative">
      <component :is="icon" class="size-6" :stroke-width="active ? 2.2 : 1.8" />
      <span
        v-if="badge > 0"
        class="absolute -right-2.5 -top-1.5 grid h-4 min-w-4 place-content-center rounded-full bg-primary px-1 text-[10px] font-bold tabular-nums text-white"
      >
        {{ badge > 99 ? "99+" : badge }}
      </span>
    </span>
    {{ label }}
  </button>
</template>

<script setup lang="ts">
import type { Component } from "vue";

defineProps<{ label: string; icon: Component; active: boolean; badge: number }>();
defineEmits<{ open: [] }>();
</script>
