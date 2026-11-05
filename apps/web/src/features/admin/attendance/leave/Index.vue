<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <CalendarOff class="size-4 text-primary" />
      {{ $t("attendance.leave.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <AttendanceNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <ChoiceButton v-for="tab in LEAVE_TABS" :key="tab" :active="status === tab" @click="status = tab">
          {{ $t(`attendance.leave.tabs.${tab}`) }}
        </ChoiceButton>
        <Input v-model="search" class="ml-auto h-11 w-full sm:w-64" :placeholder="$t('attendance.leave.search')" />
        <Button v-if="canUpdate" type="button" class="min-h-11" @click="fileOpen = true">
          <Plus class="mr-1 size-4" />
          {{ $t("attendance.leave.fileFor") }}
        </Button>
      </div>

      <ul class="min-h-0 flex-1 space-y-2 overflow-y-auto">
        <LeaveRow v-for="request in rows" :key="request.id" :request="request" show-name>
          <template #actions>
            <Button v-if="canUpdate && request.status === 'pending'" type="button" size="sm" class="min-h-9" @click="decide(request)">
              {{ $t("attendance.leave.review") }}
            </Button>
          </template>
        </LeaveRow>
        <li v-if="!rows.length && !query.isPending.value" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">
          {{ $t("attendance.leave.empty") }}
        </li>
      </ul>

      <div v-if="pageCount > 1" class="flex justify-end">
        <TablePager v-model:page="page.pageIndex" :page-count="pageCount" :loading="query.isFetching.value" />
      </div>
    </div>
  </ContentWrap>

  <LeaveDecideDialog v-model:open="decideOpen" :request="selected" />
  <LeaveRequestDialog v-model:open="fileOpen" for-staff :branches="branchChoices" :default-branch-id="branchId" :staff="staff" />
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { CalendarOff, Plus } from "lucide-vue-next";
import TablePager from "@/components/common/TablePager.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/features/admin/components";
import { BranchPicker } from "@/features/admin/pos";
import { useShiftRoster } from "@/features/admin/attendance/queries";
import { todayInVietnam } from "@/lib/businessDate";
import { mondayOf, addDays } from "@bongcun/core/attendance";
import type { LeaveRequest } from "@bongcun/core/attendance";
import AttendanceNav from "../AttendanceNav.vue";
import ChoiceButton from "./ChoiceButton.vue";
import LeaveDecideDialog from "./LeaveDecideDialog.vue";
import LeaveRequestDialog from "./LeaveRequestDialog.vue";
import LeaveRow from "./LeaveRow.vue";
import { LEAVE_TABS, useLeaveBoard } from "./useLeaveBoard";

const auth = useAuthStore();
const { branches, branchId, selectBranch } = useCurrentBranch();
const canUpdate = computed(() => auth.can("attendance", "UPDATE"));

const { status, search, page, query, rows, pageCount } = useLeaveBoard(branchId);

const selected = ref<LeaveRequest | null>(null);
const decideOpen = ref(false);
const decide = (request: LeaveRequest) => {
  selected.value = request;
  decideOpen.value = true;
};

// Filing for somebody: the people of the branch come from the roster, which is already cached by the other tabs.
const fileOpen = ref(false);
const monday = mondayOf(todayInVietnam());
const roster = useShiftRoster(branchId, monday, addDays(monday, 6));
const staff = computed(() => roster.data.value?.staff ?? []);
const branchChoices = computed(() => branches.value.filter((branch) => branch.id === branchId.value).map((branch) => ({ id: branch.id, name: branch.name })));
</script>
