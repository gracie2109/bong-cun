<template>
  <label class="flex cursor-pointer items-start gap-3 rounded-2xl border-2 p-3.5 transition-colors duration-200"
    :class="checked ? 'border-sage bg-sage-soft' : 'border-border hover:border-foreground/30'">
    <Checkbox :checked="checked" class="mt-0.5" @update:checked="emit('toggle', pick)" />
    <span class="min-w-0">
      <span class="block text-sm font-semibold">{{ pick.name }}</span>
      <span v-if="detail" class="block truncate text-xs text-muted-foreground">{{ detail }}</span>
      <span class="block text-xs text-muted-foreground">{{ duration(pick.minutes) }}</span>
    </span>
  </label>
</template>

<script lang="ts" setup>
import { Checkbox } from "@/components/ui/checkbox";
import { useDurationLabel } from "@/composables/spa/useDurationLabel";
import type { BookingPick } from "@bongcun/core/spa";

defineProps<{ pick: BookingPick; checked: boolean; detail?: string }>();
const emit = defineEmits<{ toggle: [pick: BookingPick] }>();

const duration = useDurationLabel();
</script>
