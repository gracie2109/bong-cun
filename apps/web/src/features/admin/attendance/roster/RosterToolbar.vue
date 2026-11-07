<template>
  <div class="flex flex-wrap items-center gap-2">
    <WeekRangePicker :monday="monday" :label="label" @previous="emit('previous')" @next="emit('next')" @select="(value) => emit('select', value)" />
    <Button variant="outline" :disabled="isThisWeek" @click="emit('today')">{{ $t("attendance.roster.thisWeek") }}</Button>
    <div class="ml-auto flex flex-wrap items-center gap-2">
      <slot name="publish" />
      <RosterPendingButton :count="pendingCount" />
    </div>
    <Button v-if="canCreate" variant="outline" :disabled="isPastWeek" :title="isPastWeek ? $t('attendance.roster.pastWeek') : undefined" @click="emit('copy')">
      <Copy class="mr-1 size-4" />
      {{ $t("attendance.roster.copyWeek") }}
    </Button>
  </div>
</template>

<script lang="ts" setup>
import { Copy } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import WeekRangePicker from "../shared/WeekRangePicker.vue";
import RosterPendingButton from "./RosterPendingButton.vue";

defineProps<{ monday: string; label: string; isThisWeek: boolean; isPastWeek: boolean; canCreate: boolean; pendingCount: number }>();
const emit = defineEmits<{ previous: []; next: []; select: [monday: string]; today: []; copy: [] }>();
</script>
