<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <UserRound class="size-4 text-primary" />
      {{ $t("attendance.me.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <AttendanceNav />
      <div class="grid min-h-0 flex-1 content-start gap-4 overflow-y-auto xl:grid-cols-2">
        <MyScheduleList :shifts="upcoming" :leaves="leaves" />
        <MyEntriesTable :entries="entries" />
      </div>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { UserRound } from "lucide-vue-next";
import { ContentWrap, Header } from "@/features/admin/components";
import AttendanceNav from "../AttendanceNav.vue";
import MyEntriesTable from "./MyEntriesTable.vue";
import MyScheduleList from "./MyScheduleList.vue";
import { useMyAttendance } from "./useMySchedule";

const { upcoming, entries, leaves } = useMyAttendance();
</script>
