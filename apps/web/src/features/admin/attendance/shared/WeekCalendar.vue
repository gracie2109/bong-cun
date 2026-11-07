<template>
  <div class="w-72 select-none p-3" @mouseleave="hovered = ''">
    <div class="mb-2 flex items-center justify-between">
      <Button type="button" size="icon" variant="ghost" class="size-9" :aria-label="$t('attendance.roster.previousMonth')" @click="shiftMonth(-1)">
        <ChevronLeft class="size-4" />
      </Button>
      <p class="text-sm font-semibold tabular-nums">{{ $t("attendance.roster.monthTitle", { month: Number(viewMonth.slice(5, 7)), year: viewMonth.slice(0, 4) }) }}</p>
      <Button type="button" size="icon" variant="ghost" class="size-9" :aria-label="$t('attendance.roster.nextMonth')" @click="shiftMonth(1)">
        <ChevronRight class="size-4" />
      </Button>
    </div>

    <div class="grid grid-cols-[2rem_repeat(7,1fr)] gap-y-0.5 text-center text-sm">
      <span class="py-1 text-[11px] font-semibold text-muted-foreground">{{ $t("attendance.roster.weekShort") }}</span>
      <span v-for="weekday in 7" :key="weekday" class="py-1 text-[11px] font-semibold text-muted-foreground">{{ $t(`attendance.weekday.${weekday}`) }}</span>

      <template v-for="week in weeks" :key="week.monday">
        <span class="flex items-center justify-center rounded-l-md text-[11px] tabular-nums text-muted-foreground" :class="rowClass(week.monday)">{{ isoWeekOf(week.monday).week }}</span>
        <button
          v-for="(day, index) in week.days"
          :key="day"
          type="button"
          class="h-9 tabular-nums transition-colors"
          :class="[rowClass(week.monday), index === 6 && 'rounded-r-md', day.slice(0, 7) !== viewMonth.slice(0, 7) && !isSelected(week.monday) && 'text-muted-foreground/50', day === today && 'font-bold underline underline-offset-4']"
          :aria-label="day"
          :aria-pressed="isSelected(week.monday)"
          @mouseenter="hovered = week.monday"
          @focus="hovered = week.monday"
          @click="emit('select', week.monday)"
        >
          {{ Number(day.slice(8)) }}
        </button>
      </template>
    </div>

    <div class="mt-2 flex items-center justify-between border-t pt-2">
      <p class="text-xs text-muted-foreground">{{ $t("attendance.roster.weekPicked", { week: `${picked.year}-${picked.week}` }) }}</p>
      <Button type="button" size="sm" variant="ghost" class="h-8 text-xs" @click="emit('select', mondayOf(today))">{{ $t("attendance.roster.thisWeek") }}</Button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { ChevronLeft, ChevronRight } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { todayInVietnam } from "@/lib/businessDate";
import { addMonths, isoWeekOf, mondayOf } from "@bongcun/core/attendance";
import { weeksOfMonth } from "./weekCalendar";

/** A month grid where a whole week is the unit: hover paints the row, a click picks the week. */
const props = defineProps<{ monday: string }>();
const emit = defineEmits<{ select: [monday: string] }>();

const today = todayInVietnam();
const viewMonth = ref(`${props.monday.slice(0, 7)}-01`);
const hovered = ref("");
const weeks = computed(() => weeksOfMonth(viewMonth.value));
const picked = computed(() => isoWeekOf(props.monday));

const isSelected = (monday: string) => monday === props.monday;
const rowClass = (monday: string) => (isSelected(monday) ? "bg-primary text-primary-foreground font-semibold" : hovered.value === monday ? "bg-primary/10" : "hover:bg-primary/10");
const shiftMonth = (months: number) => (viewMonth.value = addMonths(viewMonth.value, months));

// Opening on another week (arrows, "this week") brings the grid to its month.
watch(
  () => props.monday,
  (value) => (viewMonth.value = `${value.slice(0, 7)}-01`)
);
</script>
