<template>
  <div class="flex gap-2">
    <ChoiceButton :active="modelValue === 'summary'" @click="emit('update:modelValue', 'summary')">{{ $t("attendance.timesheet.tabs.summary") }}</ChoiceButton>
    <ChoiceButton :active="modelValue === 'grid'" @click="emit('update:modelValue', 'grid')">{{ $t("attendance.timesheet.tabs.grid") }}</ChoiceButton>
  </div>
</template>

<script lang="ts" setup>
import ChoiceButton from "../leave/ChoiceButton.vue";

export type TimesheetView = "summary" | "grid";

defineProps<{ modelValue: TimesheetView }>();
const emit = defineEmits<{ "update:modelValue": [value: TimesheetView] }>();
</script>
