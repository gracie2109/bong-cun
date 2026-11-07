<template>
  <div class="flex flex-wrap items-center gap-2">
    <WeekRangePicker :monday="monday" :label="label" @previous="emit('previous')" @next="emit('next')" @select="(value) => emit('select', value)" />
    <Button variant="outline" :disabled="isFirstWeek" @click="emit('reset')">{{ $t("attendance.register.nextWeek") }}</Button>
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import WeekRangePicker from "../shared/WeekRangePicker.vue";

defineProps<{ monday: string; label: string; isFirstWeek: boolean }>();
const emit = defineEmits<{ previous: []; next: []; select: [monday: string]; reset: [] }>();
</script>
