<template>
  <div class="flex items-center rounded-xl border bg-white p-1" role="tablist">
    <button
      v-for="item in VIEWS"
      :key="item"
      type="button"
      role="tab"
      :aria-selected="modelValue === item"
      class="min-h-9 rounded-lg px-3 text-sm font-semibold transition-colors"
      :class="modelValue === item ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
      @click="emit('update:modelValue', item)"
    >
      {{ $t(`attendance.roster.views.${item}`) }}
    </button>
  </div>
</template>

<script lang="ts" setup>
export type RosterView = "staff" | "shift";
const VIEWS: RosterView[] = ["staff", "shift"];

defineProps<{ modelValue: RosterView }>();
const emit = defineEmits<{ "update:modelValue": [value: RosterView] }>();
</script>
