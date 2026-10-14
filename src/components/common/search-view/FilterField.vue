<template>
  <div class="flex flex-col gap-1.5">
    <label class="text-xs font-medium text-muted-foreground">{{ label }}</label>
    <slot />
  </div>
</template>

<script lang="ts" setup>
/** A labelled cell of the filter popover grid. */
defineProps<{ label: string }>();
</script>
