<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <BellRing class="size-4 text-primary" />
      {{ $t("medical.reminders.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <MedicalNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <div class="flex gap-1 rounded-xl border bg-white p-1">
        <button
          v-for="item in REMINDER_SCOPES"
          :key="item"
          type="button"
          class="flex-1 rounded-lg px-3 py-2 text-sm font-semibold transition-colors"
          :class="scope === item ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
          @click="scope = item"
        >
          {{ $t(`medical.reminders.scope.${item}`) }}
        </button>
      </div>

      <SearchView
        v-model:search="search"
        :placeholder="$t('medical.reminders.searchPlaceholder')"
        :active-count="activeCount"
        :refreshing="listQuery.isFetching.value"
        @open-filters="syncDraft"
        @apply="apply"
        @reset-filters="resetDraft"
        @clear="clearAll"
        @refresh="listQuery.refetch()"
      >
        <template #actions><ExportMenu :exporter="exporter" compact /></template>
      </SearchView>

      <PagedTableCard class="min-h-0 flex-1" v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total" :loading="listQuery.isFetching.value">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("medical.reminders.pet") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("medical.reminders.owner") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("medical.reminders.what") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("medical.reminders.dueOn") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("medical.reminders.called") }}</th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            <TableStateRows :filtered="isFiltered" @clear="clearAll" :colspan="6" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('medical.reminders.empty')" />
            <ReminderRow v-for="row in rows" :key="row.vaccinationId ?? row.visitId ?? row.petId" :reminder="row" :can-mark="canMark" @mark="marking = row" />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <RemindDialog :open="!!marking" :reminder="marking" :busy="markBusy" @update:open="marking = null" @confirm="confirmMark" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { BellRing } from "lucide-vue-next";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import { SearchView } from "@/components/common/search-view";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { REMINDER_SCOPES } from "@bongcun/core/medical";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "@/views/admin/pos/components/BranchPicker.vue";
import MedicalNav from "../MedicalNav.vue";
import ReminderRow from "./ReminderRow.vue";
import RemindDialog from "./RemindDialog.vue";
import { useReminders } from "./useReminders";
import { useRemindersExport } from "./useRemindersExport";

const { branches, branch, branchId, selectBranch } = useCurrentBranch();
const {
  search, page, filter, activeCount, isFiltered, apply, resetDraft, clearAll, syncDraft, scope,
  listQuery, rows, total, pageCount, canMark, marking, confirmMark, markBusy,
} = useReminders(branchId);
const exporter = useRemindersExport(branchId, filter, () => branch.value?.name);
</script>
