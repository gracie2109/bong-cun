<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <History class="size-4 text-primary" />
      {{ $t("attendance.history.title") }}
    </h1>
  </Header>

  <ContentWrap fill wide>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <AttendanceNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <HistoryFilterFields
        v-model:from="list.from.value"
        v-model:to="list.to.value"
        v-model:user-id="list.userId.value"
        v-model:entity="list.entity.value"
        v-model:published-only="list.publishedOnly.value"
        :staff="staff"
      />

      <ul class="min-h-0 flex-1 space-y-2 overflow-y-auto">
        <HistoryRow v-for="row in list.rows.value" :key="row.id" :row="row" />
        <li v-if="!list.rows.value.length && !list.query.isPending.value" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">
          {{ $t("attendance.history.empty") }}
        </li>
      </ul>

      <div v-if="list.pageCount.value > 1" class="flex justify-end">
        <TablePager v-model:page="list.page.value" :page-count="list.pageCount.value" :loading="list.query.isFetching.value" />
      </div>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { History } from "lucide-vue-next";
import TablePager from "@/components/common/TablePager.vue";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { ContentWrap, Header } from "@/features/admin/components";
import { BranchPicker } from "@/features/admin/pos";
import { useShiftRoster } from "@/features/admin/attendance/queries";
import { todayInVietnam } from "@/lib/businessDate";
import { addDays } from "@bongcun/core/attendance";
import AttendanceNav from "../AttendanceNav.vue";
import HistoryFilterFields from "./HistoryFilterFields.vue";
import HistoryRow from "./HistoryRow.vue";
import { useHistoryList } from "./useHistoryList";

const { branches, branchId, selectBranch } = useCurrentBranch();
const list = useHistoryList(branchId);

// The people of the branch, for the filter; the roster call also lists staff without shifts.
const today = todayInVietnam();
const roster = useShiftRoster(branchId, today, addDays(today, 6));
const staff = computed(() => roster.data.value?.staff ?? []);
</script>
