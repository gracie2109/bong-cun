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
        </Button>
      </PopoverTrigger>
      <PopoverContent class="w-auto p-0" align="start">
        <RangeCalendar
          :model-value="range"
          :placeholder="placeholder"
          :week-starts-on="1"
          :locale="locale"
          prevent-deselect
          @update:model-value="onSelect"
          @update:placeholder="(value) => (placeholder = value)"
        />
      </PopoverContent>
    </Popover>
    <Button size="icon" variant="ghost" class="size-10" :aria-label="$t('attendance.roster.nextWeek')" @click="emit('next')">
      <ChevronRight class="size-4" />
    </Button>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { CalendarDays as CalendarIcon, ChevronLeft, ChevronRight } from "lucide-vue-next";
import type { DateValue } from "@internationalized/date";
import { Button } from "@/components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { RangeCalendar } from "@/components/ui/range-calendar";
import { useWeekRange } from "./useWeekRange";

/** Shows the week as a Monday to Sunday range; picking any day in the calendar snaps to that day's week. */
const props = defineProps<{ monday: string; label: string }>();
const emit = defineEmits<{ previous: []; next: []; select: [monday: string] }>();

const { locale: appLocale } = useI18n();
const locale = computed(() => (appLocale.value === "en" ? "en-US" : "vi-VN"));
const open = ref(false);
const { range, placeholder, pick } = useWeekRange(() => props.monday);

const onSelect = (value: { start?: DateValue }) => {
  const monday = pick(value.start);
  if (!monday) return;
  emit("select", monday);
  open.value = false;
};

watch(open, (value) => value && (placeholder.value = range.value.start));
</script>
