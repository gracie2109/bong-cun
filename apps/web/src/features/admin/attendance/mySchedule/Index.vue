<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <CalendarDays class="size-4 text-primary" />
      {{ $t("attendance.mySchedule.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <AttendanceNav />
      <div class="flex flex-wrap items-center gap-2">
        <WeekRangePicker :monday="monday" :label="label" @previous="previous" @next="next" @select="select" />
        <Button variant="outline" :disabled="isThisWeek" @click="thisWeek">{{ $t("attendance.roster.thisWeek") }}</Button>
        <p class="ml-auto text-sm text-muted-foreground">{{ $t("attendance.mySchedule.count", { n: shiftCount }) }}</p>
      </div>

      <p v-if="!query.isPending.value && shiftCount === 0" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">
        {{ $t("attendance.mySchedule.empty") }}
      </p>

      <ul class="min-h-0 flex-1 space-y-2 overflow-y-auto">
        <MyDayCard v-for="day in days" :key="day.date" :day="day" :is-today="day.date === today" :past="day.date < today" />
      </ul>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { CalendarDays } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { ContentWrap, Header } from "@/features/admin/components";
import AttendanceNav from "../AttendanceNav.vue";
import WeekRangePicker from "../shared/WeekRangePicker.vue";
import MyDayCard from "./MyDayCard.vue";
import { useMyWeek } from "./useMyWeek";

const { today, monday, label, query, days, shiftCount, isThisWeek, previous, next, select, thisWeek } = useMyWeek();
</script>
