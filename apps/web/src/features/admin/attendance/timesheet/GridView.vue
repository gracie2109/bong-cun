<template>
  <div class="flex min-h-0 flex-1 flex-col gap-3">
    <div class="flex flex-wrap items-center gap-2">
      <Button type="button" variant="outline" size="icon" class="size-11" :aria-label="$t('attendance.timesheet.prevMonth')" @click="step(-1)">
        <ChevronLeft class="size-4" />
      </Button>
      <p class="min-w-32 text-center font-semibold">{{ $t("attendance.timesheet.monthLabel", { month: month.slice(5, 7), year: month.slice(0, 4) }) }}</p>
      <Button type="button" variant="outline" size="icon" class="size-11" :aria-label="$t('attendance.timesheet.nextMonth')" @click="step(1)">
        <ChevronRight class="size-4" />
      </Button>
      <Button type="button" variant="ghost" class="min-h-11" @click="thisMonth">{{ $t("attendance.timesheet.thisMonth") }}</Button>
    </div>
    <MonthGrid v-if="grid" :grid="grid" />
    <p v-else class="text-sm text-muted-foreground">{{ $t("attendance.timesheet.loading") }}</p>
    <GridLegend />
  </div>
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import { ChevronLeft, ChevronRight } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import GridLegend from "./GridLegend.vue";
import MonthGrid from "./MonthGrid.vue";
import { useMonthGrid } from "./useTimesheetGrid";

const props = defineProps<{ branchId: string | undefined }>();
const { month, grid, step, thisMonth } = useMonthGrid(toRef(props, "branchId"));
</script>
