<template>
  <div class="flex items-center rounded-xl border bg-white p-1">
    <Button size="icon" variant="ghost" class="size-10" :aria-label="$t('attendance.roster.previousWeek')" @click="emit('previous')">
      <ChevronLeft class="size-4" />
    </Button>
    <Popover v-model:open="open">
      <PopoverTrigger as-child>
        <Button variant="ghost" class="min-w-52 gap-2 px-2 text-sm font-semibold tabular-nums">
          <CalendarIcon class="size-4 text-muted-foreground" />
          {{ label }}
          <span class="rounded-md bg-muted px-1.5 py-0.5 text-[11px] font-semibold text-muted-foreground">{{ $t("attendance.roster.weekBadge", { week: isoWeekOf(monday).week }) }}</span>
        </Button>
      </PopoverTrigger>
      <PopoverContent class="w-auto p-0" align="start">
        <WeekCalendar :monday="monday" @select="onSelect" />
      </PopoverContent>
    </Popover>
    <Button size="icon" variant="ghost" class="size-10" :aria-label="$t('attendance.roster.nextWeek')" @click="emit('next')">
      <ChevronRight class="size-4" />
    </Button>
  </div>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { CalendarDays as CalendarIcon, ChevronLeft, ChevronRight } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { isoWeekOf } from "@bongcun/core/attendance";
import WeekCalendar from "./WeekCalendar.vue";

/** Shows the week as a Monday to Sunday range; the calendar picks a whole week at a time. */
defineProps<{ monday: string; label: string }>();
const emit = defineEmits<{ previous: []; next: []; select: [monday: string] }>();

const open = ref(false);
const onSelect = (monday: string) => {
  emit("select", monday);
  open.value = false;
};
</script>
