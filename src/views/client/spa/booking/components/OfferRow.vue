<template>
  <label class="flex cursor-pointer items-start gap-3 rounded-lg border p-3 hover:bg-muted/40" :class="checked && 'border-primary bg-primary/5'">
    <Checkbox :checked="checked" class="mt-0.5" @update:checked="emit('toggle', pick)" />
    <span class="min-w-0">
      <span class="block text-sm font-medium">{{ pick.name }}</span>
      <span v-if="detail" class="block truncate text-xs text-muted-foreground">{{ detail }}</span>
      <span class="block text-xs text-muted-foreground">{{ duration(pick.minutes) }}</span>
    </span>
  </label>
</template>

<script lang="ts" setup>
import { Checkbox } from "@/components/ui/checkbox";
import { useDurationLabel } from "@/composables/spa/useDurationLabel";
import type { BookingPick } from "@/types/spaWeb";

defineProps<{ pick: BookingPick; checked: boolean; detail?: string }>();
const emit = defineEmits<{ toggle: [pick: BookingPick] }>();

const duration = useDurationLabel();
</script>
