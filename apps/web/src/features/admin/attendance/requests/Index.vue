<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <ClipboardCheck class="size-4 text-primary" />
      {{ $t("attendance.requests.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <AttendanceNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <ChoiceButton v-for="tab in REQUEST_TABS" :key="tab" :active="status === tab" @click="status = tab">
          {{ $t(`attendance.leave.tabs.${tab}`) }}
        </ChoiceButton>
        <Input v-model="from" type="date" class="h-11 w-40" :aria-label="$t('attendance.requests.from')" />
        <Input v-model="to" type="date" class="h-11 w-40" :min="from" :aria-label="$t('attendance.requests.to')" />
        <Input v-model="search" class="ml-auto h-11 w-full sm:w-64" :placeholder="$t('attendance.leave.search')" />
      </div>

      <RequestBulkBar
        v-if="canDecide && status === 'pending'"
        :count="selection.count.value"
        :all-ticked="selection.allTicked.value"
        :has-tickable="selection.tickable.value.length > 0"
        @toggle-all="selection.toggleAll"
        @decide="openDecide(selection.ids.value)"
      />

      <ul class="min-h-0 flex-1 space-y-2 overflow-y-auto">
        <RequestRow
          v-for="request in rows"
          :key="request.id"
          :request="request"
          :selectable="canDecide && canTick(request)"
          :selected="selection.has(request.id)"
          @toggle="selection.toggle(request.id)"
        >
          <template #actions>
            <Button v-if="canDecide && canTick(request)" type="button" size="sm" class="min-h-9" @click="openDecide([request.id])">
              {{ $t("attendance.leave.review") }}
            </Button>
          </template>
        </RequestRow>
        <li v-if="!rows.length && !query.isPending.value" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">
          {{ $t("attendance.requests.empty") }}
        </li>
      </ul>

      <div v-if="pageCount > 1" class="flex justify-end">
        <TablePager v-model:page="page.pageIndex" :page-count="pageCount" :loading="query.isFetching.value" />
      </div>
    </div>
  </ContentWrap>

  <DecideRequestsDialog v-model:open="decideOpen" :ids="decideIds" :names="names" @done="selection.clear" />
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { ClipboardCheck } from "lucide-vue-next";
import TablePager from "@/components/common/TablePager.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/features/admin/components";
import { BranchPicker } from "@/features/admin/pos";
import AttendanceNav from "../AttendanceNav.vue";
import ChoiceButton from "../leave/ChoiceButton.vue";
import DecideRequestsDialog from "./DecideRequestsDialog.vue";
import RequestBulkBar from "./RequestBulkBar.vue";
import RequestRow from "./RequestRow.vue";
import { REQUEST_TABS, useRequestBoard } from "./useRequestBoard";
import { canTick, useRequestSelection } from "./useRequestSelection";

const auth = useAuthStore();
const { branches, branchId, selectBranch } = useCurrentBranch();
const canDecide = computed(() => auth.can("attendance", "CREATE"));

const { status, from, to, search, page, query, rows, pageCount } = useRequestBoard(branchId);
const selection = useRequestSelection(rows, computed(() => `${status.value}|${branchId.value}`));
const names = computed(() => Object.fromEntries(rows.value.map((row) => [row.id, row.userName])));

const decideOpen = ref(false);
const decideIds = ref<string[]>([]);
const openDecide = (ids: string[]) => {
  decideIds.value = [...ids];
  decideOpen.value = true;
};
</script>
