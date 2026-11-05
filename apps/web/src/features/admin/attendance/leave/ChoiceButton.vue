<template>
  <button
    type="button"
    class="min-h-11 rounded-lg border px-3 text-sm font-semibold"
    :class="active ? 'border-primary bg-primary/10 text-primary ring-2 ring-primary' : 'bg-white text-muted-foreground hover:bg-muted'"
  >
    <slot />
  </button>
</template>

<script lang="ts" setup>
defineProps<{ active: boolean }>();
</script>
