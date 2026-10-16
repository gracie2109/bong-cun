<template>
  <div class="flex flex-wrap gap-2" role="group" :aria-label="label">
    <button
      v-for="option in options"
      :key="option.id"
      type="button"
      class="h-10 rounded-full border px-4 text-sm font-semibold transition-colors duration-200"
      :class="option.id === modelValue ? 'border-foreground bg-foreground text-white' : 'border-border bg-white hover:border-foreground/40'"
      :aria-pressed="option.id === modelValue"
      @click="$emit('update:modelValue', option.id)"
    >
      {{ option.name }}
    </button>
  </div>
</template>

<script lang="ts" setup>
/** A row of pill toggles where exactly one is picked (branch, species...). */
defineProps<{ options: { id: string; name: string }[]; modelValue: string | null | undefined; label: string }>();
defineEmits<{ "update:modelValue": [id: string] }>();
</script>
