<template>
  <button
    type="button"
    class="relative flex w-full items-center rounded-lg px-3 text-left transition-colors duration-200"
    :class="[small ? 'min-h-9 text-[13px]' : 'min-h-10 text-sm', active ? 'bg-accent font-semibold text-accent-foreground' : 'text-foreground/80 hover:bg-muted hover:text-foreground']"
    :aria-pressed="active"
  >
    <span
      class="absolute left-0 top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-full bg-primary transition-transform duration-300 ease-out-quart"
      :class="active ? 'scale-y-100' : 'scale-y-0'"
      aria-hidden="true"
    />
    <span class="truncate"><slot /></span>
  </button>
</template>

<script lang="ts" setup>
defineProps<{ active: boolean; small?: boolean }>();
</script>
