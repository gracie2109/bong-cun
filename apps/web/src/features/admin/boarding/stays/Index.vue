<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <ListChecks class="size-4 text-primary" />
      {{ $t("boarding.stays.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <BoardingNav />
        <div class="flex flex-wrap items-center gap-2">
          <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
          <Button v-if="canCreate" :disabled="!branchId" @click="openNew">
            <Plus class="mr-2 size-4" />
            {{ $t("boarding.stays.new") }}
          </Button>
        </div>
      </div>

      <SearchView
        v-model:search="search"
        :placeholder="$t('boarding.stays.searchPlaceholder')"
        :active-count="activeCount"
        :refreshing="listQuery.isFetching.value"
        @open-filters="syncDraft"
        @apply="apply"
        @reset-filters="resetDraft"
        @clear="clearAll"
        @refresh="listQuery.refetch()"
      >
        <template #filters><StayFilterFields v-model:from="draft.from" v-model:to="draft.to" v-model:status="draft.status" /></template>
        <template #actions><ExportMenu :exporter="exporter" compact /></template>
      </SearchView>

      <PagedTableCard class="min-h-0 flex-1" v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total" :loading="listQuery.isFetching.value">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("boarding.stays.code") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("boarding.stays.time") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("boarding.stays.customer") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("boarding.stays.pets") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("boarding.stays.total") }}</th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            <TableStateRows :filtered="isFiltered" @clear="clearAll" :colspan="6" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('boarding.stays.empty')" />
            <StayRow
              v-for="row in rows"
              :key="row.id"
              :stay="row"
              :can-edit="canUpdate && row.status === 'booked'"
              :can-no-show="canUpdate && row.status === 'booked'"
              @edit="openEdit(row)"
              @no-show="noShow.mutate(row.id)"
            />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <StayDialog v-if="branchId" v-model:open="dialogOpen" :branch-id="branchId" :stay="editing" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { ListChecks, Plus } from "lucide-vue-next";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import { SearchView } from "@/components/common/search-view";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { usePagedList } from "@/composables/usePagedList";
import { useBoardingStays, useMarkBoardingNoShow } from "@/features/admin/boarding/queries";
import { useAuthStore } from "@/stores";
import type { BoardingStay } from "@bongcun/core/boarding";
import { ContentWrap, Header } from "@/features/admin/components";
import BranchPicker from "@/features/admin/pos/components/BranchPicker.vue";
import BoardingNav from "../BoardingNav.vue";
import StayDialog from "../stay-dialog/StayDialog.vue";
import StayFilterFields from "./StayFilterFields.vue";
import StayRow from "./StayRow.vue";
import { useStayFilters } from "./useStayFilters";
import { useStaysExport } from "./useStaysExport";

const auth = useAuthStore();
const canCreate = computed(() => auth.can("boarding", "CREATE"));
const canUpdate = computed(() => auth.can("boarding", "UPDATE"));
const { branches, branch, branchId, selectBranch } = useCurrentBranch();

const { search, page, filter, draft, activeCount, isFiltered, apply, resetDraft, clearAll, syncDraft } = useStayFilters(branchId);
const exporter = useStaysExport(branchId, filter, () => branch.value?.name);
const listQuery = useBoardingStays(branchId, page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);
const noShow = useMarkBoardingNoShow();

const dialogOpen = ref(false);
const editing = ref<BoardingStay | null>(null);

const openNew = () => {
  editing.value = null;
  dialogOpen.value = true;
};

const openEdit = (row: BoardingStay) => {
  editing.value = row;
  dialogOpen.value = true;
};
</script>
