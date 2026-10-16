<template>
  <span class="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold" :class="TONE[kind]">
    <span class="size-1.5 rounded-full bg-current" aria-hidden="true" />
    <slot />
  </span>
</template>

<script lang="ts" setup>
/** Stock as a small pill: green when it can be bought, amber when few are left, grey when sold out. */
defineProps<{ kind: "in" | "low" | "out" }>();

const TONE = {
  in: "bg-sage-soft text-sage",
  low: "bg-amber-50 text-amber-800",
  out: "bg-foreground/85 text-white",
} as const;
</script>
