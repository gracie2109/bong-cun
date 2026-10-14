<template>
  <Button
    type="button"
    variant="outline"
    size="icon"
    class="relative size-9 shrink-0 border-primary/30 text-primary hover:bg-primary/10 hover:text-primary"
    :title="label"
    :aria-label="label"
    :disabled="disabled"
  >
    <slot />
    <span
      v-if="badge"
      class="absolute -right-1.5 -top-1.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-primary px-1 text-[10px] font-semibold leading-none text-primary-foreground"
    >
      {{ badge }}
    </span>
  </Button>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";

/** A square icon button of a table toolbar; the label is its tooltip and accessible name. */
defineProps<{
  label: string;
  badge?: number;
  disabled?: boolean;
}>();
</script>
