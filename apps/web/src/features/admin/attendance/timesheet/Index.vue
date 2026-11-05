<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <TableProperties class="size-4 text-primary" />
      {{ $t("attendance.timesheet.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <AttendanceNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>
      <TimesheetTabs v-model="view" />
      <SummaryView v-if="view === 'summary'" :branch-id="branchId" :branch-name="branch?.name" />
      <GridView v-else :branch-id="branchId" />
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { TableProperties } from "lucide-vue-next";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { ContentWrap, Header } from "@/features/admin/components";
import { BranchPicker } from "@/features/admin/pos";
import AttendanceNav from "../AttendanceNav.vue";
import GridView from "./GridView.vue";
import SummaryView from "./SummaryView.vue";
import TimesheetTabs, { type TimesheetView } from "./TimesheetTabs.vue";

const { branches, branch, branchId, selectBranch } = useCurrentBranch();
const view = ref<TimesheetView>("summary");
</script>
