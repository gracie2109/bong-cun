<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <ListChecks class="size-4 text-primary" />
      {{ $t("medical.visits.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <MedicalNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <SearchView
        v-model:search="search"
        :placeholder="$t('medical.visits.searchPlaceholder')"
        :active-count="activeCount"
        :refreshing="listQuery.isFetching.value"
        @open-filters="syncDraft"
        @apply="apply"
        @reset-filters="resetDraft"
        @clear="clearAll"
        @refresh="listQuery.refetch()"
      >
        <template #filters>
          <VisitFilterFields v-model:from="draft.from" v-model:to="draft.to" v-model:status="draft.status" v-model:vet-id="draft.vetId" :vets="vets" />
        </template>
        <template #actions><ExportMenu :exporter="exporter" compact /></template>
      </SearchView>

      <PagedTableCard class="min-h-0 flex-1" v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total" :loading="listQuery.isFetching.value">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("medical.visits.code") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("medical.visits.time") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("medical.visits.pet") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("medical.visits.customer") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("medical.visits.vet") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("medical.visits.diagnosis") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("medical.visits.outcome") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("medical.visits.total") }}</th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            <TableStateRows :filtered="isFiltered" @clear="clearAll" :colspan="9" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('medical.visits.empty')" />
            <VisitRow v-for="row in rows" :key="row.id" :visit="row" />
          </tbody>
        </table>
      </PagedTableCard>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { ListChecks } from "lucide-vue-next";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import { SearchView } from "@/components/common/search-view";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { usePagedList } from "@/composables/usePagedList";
import { useMedicalVets, useMedicalVisits } from "@/features/admin/medical/queries/medicalVisits";
import { ContentWrap, Header } from "@/features/admin/components";
import { BranchPicker } from "@/features/admin/pos";
import MedicalNav from "../MedicalNav.vue";
import VisitFilterFields from "./VisitFilterFields.vue";
import VisitRow from "./VisitRow.vue";
import { useVisitFilters } from "./useVisitFilters";
import { useVisitsExport } from "./useVisitsExport";

const { branches, branch, branchId, selectBranch } = useCurrentBranch();
const { search, page, filter, draft, activeCount, isFiltered, apply, resetDraft, clearAll, syncDraft } = useVisitFilters(branchId);
const exporter = useVisitsExport(branchId, filter, () => branch.value?.name);
const listQuery = useMedicalVisits(branchId, page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);
const vetsQuery = useMedicalVets(branchId);
const vets = computed(() => vetsQuery.data.value ?? []);
</script>
