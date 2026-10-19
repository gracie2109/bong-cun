<template>
  <span
    v-if="disabled"
    class="grid size-10 place-content-center rounded-full text-muted-foreground/40"
    :aria-label="label"
    aria-disabled="true"
  >
    <slot />
  </span>
  <RouterLink
    v-else
    :to="to"
    class="grid size-10 place-content-center rounded-full border text-sm font-medium transition-colors hover:border-foreground/40"
    :class="current ? 'border-primary bg-primary text-white hover:border-primary' : 'bg-white'"
    :aria-label="label"
    :aria-current="current ? 'page' : undefined"
  >
    <slot />
  </RouterLink>
</template>

<script lang="ts" setup>
import type { RouteLocationRaw } from "vue-router";

defineProps<{ to: RouteLocationRaw; label: string; current?: boolean; disabled?: boolean }>();
</script>
